# ============================================================
# rbac.tf — Managed Identity and Role Assignments
# ============================================================
# Azure Managed Identity is the equivalent of an AWS IAM role
# attached to a compute resource. The Container App uses a
# User-Assigned Managed Identity so it can:
#   1. Pull images from ACR (AcrPull role)
#   2. Read secrets from Key Vault (Key Vault Secrets User role)
#
# Both role assignments are scoped to specific resources —
# not to the subscription or resource group. This is least
# privilege: the identity can do exactly two things and nothing
# else. No wildcard permissions anywhere.
# ============================================================

# ── User-Assigned Managed Identity ──────────────────────────
# User-assigned (vs system-assigned) means the identity has an
# independent lifecycle from the Container App — it survives
# if the app is deleted and recreated, preserving role assignments.
resource "azurerm_user_assigned_identity" "aca" {
  name                = "${var.app_name}-aca-identity"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

# ── Role: pull images from ACR ───────────────────────────────
# AcrPull allows: read image manifests, pull image layers.
# Does NOT allow: push images, delete images, admin operations.
# Scoped to: this specific ACR only.
resource "azurerm_role_assignment" "aca_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aca.principal_id
}

# ── Role: read secrets from Key Vault ───────────────────────
# Key Vault Secrets User allows: get secret values, list secrets.
# Does NOT allow: create/update/delete secrets, manage vault policies.
# Scoped to: this specific Key Vault only.
resource "azurerm_role_assignment" "aca_keyvault" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.aca.principal_id
}

# ── Role: CI/CD pipeline pushes images to ACR ───────────────
# The GitHub Actions pipeline needs AcrPush to upload built images.
# This uses a separate Service Principal (defined in CI secrets),
# not the same identity as the Container App.
# Scoped to: this specific ACR only.
#
# Note: The Service Principal itself is created outside Terraform
# (once, by an admin) and its credentials stored in GitHub secrets.
# We only manage the role assignment here.
data "azuread_service_principal" "github_actions" {
  display_name = "${var.app_name}-github-actions-sp"
}

resource "azurerm_role_assignment" "ci_acr_push" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPush"
  principal_id         = data.azuread_service_principal.github_actions.object_id
}
