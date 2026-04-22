# ============================================================
# keyvault.tf — Azure Key Vault and application secrets
# ============================================================
# Key Vault is the Azure equivalent of AWS Secrets Manager.
# Secrets are stored here and injected into the Container App
# at runtime via Key Vault references — the raw values never
# appear in Terraform state, environment variables, or logs.
#
# Access is controlled by Azure RBAC (role assignments in
# rbac.tf), not Key Vault access policies, which is the
# current recommended approach.
# ============================================================

# ── Current caller identity (needed for admin access) ───────
data "azurerm_client_config" "current" {}

# ── Key Vault ────────────────────────────────────────────────
resource "azurerm_key_vault" "main" {
  name                = "${replace(var.app_name, "-", "")}kv"  # max 24 chars, alphanumeric + hyphens
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # RBAC authorization (modern approach — replaces access policies)
  enable_rbac_authorization = true

  # Soft-delete: deleted secrets are recoverable for 90 days.
  # purge_protection: prevents permanent deletion for 90 days even by admins.
  # Both protect against accidental or malicious destruction.
  soft_delete_retention_days = 90
  purge_protection_enabled   = true

  # Network rules: only allow access from the VNet and Azure services.
  # The Container Apps platform accesses Key Vault via Azure backbone,
  # not via the public internet.
  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [azurerm_subnet.containers.id]
  }

  tags = local.common_tags
}

# ── Grant Terraform runner admin access to manage secrets ───
# The pipeline's Service Principal needs to be able to write
# secrets during terraform apply. This gives it Key Vault
# Secrets Officer on this vault only.
resource "azurerm_role_assignment" "terraform_kv_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ── Secret: database password ────────────────────────────────
# The value comes from var.db_password which is supplied as a
# CI secret — it is never written to source control.
resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = var.db_password
  key_vault_id = azurerm_key_vault.main.id

  content_type = "text/plain"

  tags = local.common_tags

  depends_on = [azurerm_role_assignment.terraform_kv_admin]
}

# ── Secret: Laravel APP_KEY ──────────────────────────────────
resource "azurerm_key_vault_secret" "app_key" {
  name         = "app-key"
  value        = var.app_key
  key_vault_id = azurerm_key_vault.main.id

  content_type = "text/plain"

  tags = local.common_tags

  depends_on = [azurerm_role_assignment.terraform_kv_admin]
}
