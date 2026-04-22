# ============================================================
# outputs.tf — Values printed after terraform apply
# ============================================================
# These outputs are used by the CI/CD pipeline and by
# developers to find deployed resource details without
# logging into the Azure portal.
# ============================================================

output "app_url" {
  description = "Public HTTPS URL of the deployed Container App"
  value       = "https://${azurerm_container_app.app.latest_revision_fqdn}"
}

output "acr_login_server" {
  description = "ACR login server — used in docker build/push commands"
  value       = azurerm_container_registry.main.login_server
}

output "mysql_fqdn" {
  description = "MySQL Flexible Server fully qualified domain name"
  value       = azurerm_mysql_flexible_server.main.fqdn
  sensitive   = true
}

output "key_vault_uri" {
  description = "Key Vault URI for manual secret management"
  value       = azurerm_key_vault.main.vault_uri
}

output "resource_group_name" {
  description = "Resource group containing all deployed resources"
  value       = azurerm_resource_group.main.name
}

output "managed_identity_client_id" {
  description = "Client ID of the Container App Managed Identity (needed for ACR auth config)"
  value       = azurerm_user_assigned_identity.aca.client_id
}
