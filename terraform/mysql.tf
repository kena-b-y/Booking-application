# ============================================================
# mysql.tf — Azure Database for MySQL Flexible Server
# ============================================================
# Flexible Server is the current-generation managed MySQL on
# Azure. It is deployed into the private db-subnet with VNet
# integration — no public endpoint, not reachable from internet.
# The container connects via the private DNS zone defined in
# vnet.tf.
# ============================================================

resource "azurerm_mysql_flexible_server" "main" {
  name                   = "${var.app_name}-mysql"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  administrator_login    = var.db_admin_username
  administrator_password = var.db_password

  # B_Standard_D1ds is the cheapest Flexible Server SKU.
  # Upgrade to D2ds_v4 or higher for production workloads.
  sku_name = "B_Standard_D1ds"
  version  = "8.0.21"

  # Private VNet integration — no public internet access
  delegated_subnet_id = azurerm_subnet.database.id
  private_dns_zone_id = azurerm_private_dns_zone.mysql.id

  storage {
    size_gb           = 20
    auto_grow_enabled = true
  }

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false # enable for production

  # High availability — disabled for cost in dev,
  # set mode = "ZoneRedundant" for production
  high_availability {
    mode = "Disabled"
  }

  tags = local.common_tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql]
}

# ── Create the application database ─────────────────────────
resource "azurerm_mysql_flexible_database" "app" {
  name                = var.db_name
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_flexible_server.main.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

# ── Firewall: allow traffic from container subnet only ───────
# The VNet integration handles routing; this rule is an extra
# defence-in-depth layer.
resource "azurerm_mysql_flexible_server_firewall_rule" "allow_containers" {
  name                = "allow-container-subnet"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_flexible_server.main.name
  start_ip_address    = "10.0.1.0"
  end_ip_address      = "10.0.1.255"
}
