locals {
  # Globally-unique names need a stable suffix. Derived from the resource group id.
  suffix = substr(sha1(azurerm_resource_group.this.id), 0, 6)

  # ACR and Key Vault names must be alphanumeric only.
  acr_name       = "${var.name_prefix}acr${local.suffix}"
  key_vault_name = "${var.name_prefix}kv${local.suffix}"

  # When container_image is empty, build and push the app image to the ACR
  # created here (see null_resource.image_build) and deploy that.
  build_image     = var.container_image == ""
  built_image     = "${azurerm_container_registry.this.login_server}/${var.image_name}:${var.image_tag}"
  container_image = local.build_image ? local.built_image : var.container_image

  otel_headers_secret_name = "otel-exporter-otlp-headers"
}

data "azurerm_client_config" "current" {}

# ---- Resource group --------------------------------------------------------

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ---- Azure Container Registry ----------------------------------------------

resource "azurerm_container_registry" "this" {
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = var.tags
}

# ---- Build & push the app image (server-side, in ACR) ----------------------
# Removes the manual "apply, then docker build/push, then apply again" step.
# `az acr build` builds the image on ACR's amd64 build agents (so no local
# Docker daemon or --platform handling is needed) and pushes it to the registry.
# The Container App depends on this, so the image always exists before the app
# is created or updated.
resource "null_resource" "image_build" {
  count = local.build_image ? 1 : 0

  # Rebuild when the image tag changes or when the app source/Dockerfile change.
  triggers = {
    image_tag  = var.image_tag
    image_name = var.image_name
    registry   = azurerm_container_registry.this.login_server
    dockerfile = filesha256("${path.module}/../Dockerfile")
    csproj     = filesha256("${path.module}/../DotNetApp.csproj")
    program_cs = filesha256("${path.module}/../Program.cs")
  }

  provisioner "local-exec" {
    # Build context is the repo root (one level up from this module).
    working_dir = "${path.module}/.."
    command     = <<-EOT
      az acr build \
        --registry ${azurerm_container_registry.this.name} \
        --image ${var.image_name}:${var.image_tag} \
        --file Dockerfile \
        .
    EOT
  }
}

# ---- User-assigned managed identity ----------------------------------------
# Used by the Container App to (a) pull from ACR and (b) read the secret from
# Key Vault, so no credentials are stored in the app config.

resource "azurerm_user_assigned_identity" "app" {
  name                = "${var.name_prefix}-app-identity"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = var.tags
}

# Allow the identity to pull images from the ACR.
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

# ---- Log Analytics + Container Apps environment ----------------------------

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.name_prefix}-logs"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_container_app_environment" "this" {
  name                       = "${var.name_prefix}-env"
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  tags                       = var.tags
}

# ---- Key Vault (secret store) ----------------------------------------------

resource "azurerm_key_vault" "this" {
  name                       = local.key_vault_name
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = var.tags
}

# Let the identity running OpenTofu write the secret.
resource "azurerm_role_assignment" "deployer_kv_admin" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Let the app's managed identity read the secret.
resource "azurerm_role_assignment" "app_kv_reader" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

# Store the OTLP headers (which carry the Authorization bearer token) as a
# Key Vault secret rather than a plaintext env var.
resource "azurerm_key_vault_secret" "otel_headers" {
  name         = local.otel_headers_secret_name
  value        = var.otel_exporter_otlp_headers
  key_vault_id = azurerm_key_vault.this.id

  # Ensure the deployer has write access before creating the secret.
  depends_on = [azurerm_role_assignment.deployer_kv_admin]
}

# ---- Container App ---------------------------------------------------------

resource "azurerm_container_app" "this" {
  name                         = "${var.name_prefix}-app"
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = azurerm_container_app_environment.this.id
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  # Pull images from ACR using the managed identity.
  registry {
    server   = azurerm_container_registry.this.login_server
    identity = azurerm_user_assigned_identity.app.id
  }

  # Reference the Key Vault secret; Container Apps resolves it via the identity.
  secret {
    name                = local.otel_headers_secret_name
    key_vault_secret_id = azurerm_key_vault_secret.otel_headers.versionless_id
    identity            = azurerm_user_assigned_identity.app.id
  }

  ingress {
    external_enabled = true
    target_port      = var.app_port
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "dot-net-app"
      image  = local.container_image
      cpu    = var.container_cpu
      memory = var.container_memory

      env {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = var.aspnetcore_environment
      }

      env {
        name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
        value = var.otel_exporter_otlp_endpoint
      }

      env {
        name  = "OTEL_EXPORTER_OTLP_PROTOCOL"
        value = var.otel_exporter_otlp_protocol
      }

      env {
        name  = "OTEL_SERVICE_NAME"
        value = var.otel_service_name
      }

      # Secret injected from Key Vault via the Container App secret reference.
      env {
        name        = "OTEL_EXPORTER_OTLP_HEADERS"
        secret_name = local.otel_headers_secret_name
      }
    }
  }

  depends_on = [
    azurerm_role_assignment.acr_pull,
    azurerm_role_assignment.app_kv_reader,
    null_resource.image_build,
  ]
}
