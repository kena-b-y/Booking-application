# ============================================================
# acr.tf — Azure Container Registry
# ============================================================
# ACR is the Azure equivalent of ECR. The Standard tier
# supports geo-replication and vulnerability scanning.
# The container app pulls images using its Managed Identity
# (assigned the AcrPull role below) — no registry credentials
# are stored anywhere.
# ============================================================

resource "azurerm_container_registry" "main" {
  name                = replace("${var.app_name}acr", "-", "") # ACR names: alphanumeric only
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"

  # Disable admin account — access is via Managed Identity only.
  # Admin credentials are a shared secret; Managed Identity is zero-secret.
  admin_enabled = false

  tags = local.common_tags
}

# ── Grant the Container App's Managed Identity pull access ──
# AcrPull is the least-privilege built-in role for reading images.
# Scoped to this specific registry — not subscription-wide.
resource "azurerm_role_assignment" "aca_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aca.principal_id
}
