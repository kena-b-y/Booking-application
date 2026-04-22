# ============================================================
# vnet.tf — Virtual Network with public and private subnets
# ============================================================
# Azure uses a single VNet with subnets rather than AWS's
# separate public/private subnet model. Subnets are isolated
# using Network Security Groups (NSGs) instead of route tables.
#
# Subnet layout:
#   10.0.1.0/24  — container-subnet  (private, Container Apps)
#   10.0.2.0/24  — db-subnet         (private, MySQL)
#   10.0.3.0/24  — appgw-subnet      (public-facing, App Gateway)
# ============================================================

resource "azurerm_virtual_network" "main" {
  name                = "${var.app_name}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]

  tags = local.common_tags
}

# ── Private subnet: Container Apps ──────────────────────────
resource "azurerm_subnet" "containers" {
  name                 = "container-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]

  # Required delegation for Container Apps Environment
  delegation {
    name = "container-apps-delegation"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# ── Private subnet: MySQL Flexible Server ───────────────────
resource "azurerm_subnet" "database" {
  name                 = "db-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]

  # Required delegation for MySQL Flexible Server
  delegation {
    name = "mysql-delegation"
    service_delegation {
      name    = "Microsoft.DBforMySQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# ── NSG: Container Apps subnet ──────────────────────────────
# Allows inbound HTTP from the VNet only (traffic arrives via
# Container Apps managed ingress, not directly from internet).
resource "azurerm_network_security_group" "containers" {
  name                = "${var.app_name}-container-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-http-inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "containers" {
  subnet_id                 = azurerm_subnet.containers.id
  network_security_group_id = azurerm_network_security_group.containers.id
}

# ── NSG: Database subnet ─────────────────────────────────────
# Only accepts MySQL traffic (3306) from the container subnet.
# No public internet access to the database.
resource "azurerm_network_security_group" "database" {
  name                = "${var.app_name}-db-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-mysql-from-containers"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-all-other-inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "database" {
  subnet_id                 = azurerm_subnet.database.id
  network_security_group_id = azurerm_network_security_group.database.id
}

# ── Private DNS zone for MySQL ───────────────────────────────
# MySQL Flexible Server with VNet integration requires a
# private DNS zone so the container can resolve the DB hostname.
resource "azurerm_private_dns_zone" "mysql" {
  name                = "${var.app_name}.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                  = "${var.app_name}-mysql-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.mysql.name
  resource_group_name   = azurerm_resource_group.main.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}
