output "app_url" {
  description = "Public HTTPS URL of the deployed Container App."
  value       = "https://${azurerm_container_app.this.ingress[0].fqdn}"
}

output "app_fqdn" {
  description = "Ingress FQDN of the Container App."
  value       = azurerm_container_app.this.ingress[0].fqdn
}

output "acr_login_server" {
  description = "ACR login server. Tag/push the app image here, e.g. <server>/dot-net-app:latest."
  value       = azurerm_container_registry.this.login_server
}

output "key_vault_name" {
  description = "Name of the Key Vault holding the OTLP headers secret."
  value       = azurerm_key_vault.this.name
}

output "otel_headers_secret_name" {
  description = "Key Vault secret name for the OTLP export headers."
  value       = azurerm_key_vault_secret.otel_headers.name
}

output "managed_identity_client_id" {
  description = "Client ID of the app's user-assigned managed identity."
  value       = azurerm_user_assigned_identity.app.client_id
}
