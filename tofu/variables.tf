variable "subscription_id" {
  type        = string
  description = "Azure subscription ID to deploy into."
}

variable "location" {
  type        = string
  description = "Azure region for all resources."
}

variable "name_prefix" {
  type        = string
  description = "Short prefix used to name resources. Lowercase alphanumeric; keep it brief since it seeds a globally-unique ACR/Key Vault name."

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,10}$", var.name_prefix))
    error_message = "name_prefix must be 2-11 chars, lowercase letters/digits, starting with a letter."
  }
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to create."
}

# ---- Container image -------------------------------------------------------

variable "container_image" {
  type        = string
  description = "Fully-qualified container image reference to deploy (e.g. myacr.azurecr.io/dotnet-app:latest). Leave empty to have this configuration build and push the app image to the ACR created here (see image_tag)."
  default     = ""
}

variable "image_tag" {
  type        = string
  description = "Tag to build/push for the app image when container_image is not set. Change this (or use a content-based value) to force a rebuild and a new Container App revision."
  default     = "latest"
}

variable "image_name" {
  type        = string
  description = "Repository name for the app image within the ACR (used when building the image here)."
  default     = "dot-net-app"
}

variable "container_cpu" {
  type        = number
  description = "vCPU allocated to the container."
  default     = 0.5
}

variable "container_memory" {
  type        = string
  description = "Memory allocated to the container (e.g. 1Gi)."
  default     = "1Gi"
}

variable "app_port" {
  type        = number
  description = "Port the app listens on inside the container."
  default     = 8080
}

variable "min_replicas" {
  type        = number
  description = "Minimum number of container replicas."
  default     = 1
}

variable "max_replicas" {
  type        = number
  description = "Maximum number of container replicas."
  default     = 3
}

# ---- OpenTelemetry (non-secret) configuration ------------------------------

variable "otel_exporter_otlp_endpoint" {
  type        = string
  description = "OTLP exporter endpoint (OTEL_EXPORTER_OTLP_ENDPOINT). Not a secret."
}

variable "otel_exporter_otlp_protocol" {
  type        = string
  description = "OTLP exporter protocol (OTEL_EXPORTER_OTLP_PROTOCOL). Not a secret."
}

variable "otel_service_name" {
  type        = string
  description = "Service name reported in telemetry (OTEL_SERVICE_NAME). Not a secret."
}

variable "aspnetcore_environment" {
  type        = string
  description = "ASPNETCORE_ENVIRONMENT value."
}

# ---- OpenTelemetry secret --------------------------------------------------
# OTEL_EXPORTER_OTLP_HEADERS carries the Authorization bearer token, so it is
# treated as a secret: stored in Key Vault and injected as a Container App
# secret reference rather than a plaintext env var in state/config.

variable "otel_exporter_otlp_headers" {
  type        = string
  description = "OTLP export headers (OTEL_EXPORTER_OTLP_HEADERS), e.g. 'Authorization=Bearer <token>'. Secret."
  sensitive   = true
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
  default = {
    application = "dot-net-app"
    managed-by  = "opentofu"
  }
}
