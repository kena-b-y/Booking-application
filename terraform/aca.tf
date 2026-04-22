# ============================================================
# aca.tf — Azure Container Apps (compute layer)
# ============================================================
# Azure Container Apps is the serverless container platform —
# the Azure equivalent of AWS ECS Fargate. It handles:
#   - Container scheduling and scaling
#   - Built-in HTTPS ingress (no separate load balancer needed)
#   - Rolling deployments (zero downtime)
#   - Scale-to-zero when idle (cost saving in dev)
#
# Secrets are pulled from Key Vault at runtime via the
# Managed Identity — the container never receives raw credentials.
# ============================================================

# ── Log Analytics Workspace (required by Container Apps) ────
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.app_name}-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.common_tags
}

# ── Container Apps Environment ───────────────────────────────
# The Environment is the shared infrastructure boundary —
# equivalent to an ECS Cluster. Multiple Container Apps can
# share one Environment.
resource "azurerm_container_app_environment" "main" {
  name                       = "${var.app_name}-env"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  # Deploy into the private container subnet
  infrastructure_subnet_id = azurerm_subnet.containers.id

  tags = local.common_tags
}

# ── Container App ────────────────────────────────────────────
resource "azurerm_container_app" "app" {
  name                         = "${var.app_name}-app"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name

  # "Multiple" allows rolling updates — new revision runs before
  # old one is deactivated (zero-downtime deploy).
  revision_mode = "Multiple"

  # Use the Managed Identity to pull from ACR — no credentials stored
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aca.id]
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = azurerm_user_assigned_identity.aca.id
  }

  # ── Secrets pulled from Key Vault ───────────────────────────
  # Key Vault references mean the actual secret value is never
  # stored in the Container App configuration — it is fetched
  # at container startup by the platform.
  secret {
    name                = "db-password"
    key_vault_secret_id = azurerm_key_vault_secret.db_password.id
    identity            = azurerm_user_assigned_identity.aca.id
  }

  secret {
    name                = "app-key"
    key_vault_secret_id = azurerm_key_vault_secret.app_key.id
    identity            = azurerm_user_assigned_identity.aca.id
  }

  template {
    # ── Scaling rules ──────────────────────────────────────────
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    # Scale out when concurrent HTTP requests exceed 10 per replica
    custom_scale_rule {
      name             = "http-scaling"
      custom_rule_type = "http"
      metadata = {
        concurrentRequests = "10"
      }
    }

    container {
      name   = "laravel-app"
      image  = "${azurerm_container_registry.main.login_server}/${var.app_name}:${var.image_tag}"
      cpu    = var.container_cpu
      memory = var.container_memory

      # ── Environment variables ────────────────────────────────
      # Non-sensitive config is passed as plain env vars.
      # Sensitive values reference the secrets block above.
      env {
        name  = "APP_ENV"
        value = "production"
      }
      env {
        name  = "APP_DEBUG"
        value = "false"
      }
      env {
        name        = "APP_KEY"
        secret_name = "app-key"
      }
      env {
        name  = "DB_CONNECTION"
        value = "mysql"
      }
      env {
        name  = "DB_HOST"
        value = azurerm_mysql_flexible_server.main.fqdn
      }
      env {
        name  = "DB_PORT"
        value = "3306"
      }
      env {
        name  = "DB_DATABASE"
        value = var.db_name
      }
      env {
        name  = "DB_USERNAME"
        value = var.db_admin_username
      }
      env {
        name        = "DB_PASSWORD"
        secret_name = "db-password"
      }

      # ── Liveness probe ──────────────────────────────────────
      # Container Apps restarts the container if this fails.
      liveness_probe {
        transport = "HTTP"
        path      = "/api/health"
        port      = 80

        initial_delay           = 10
        period_seconds          = 30
        failure_count_threshold = 3
      }

      # ── Readiness probe ─────────────────────────────────────
      # Traffic is only sent to the container after this passes.
      readiness_probe {
        transport = "HTTP"
        path      = "/api/health"
        port      = 80

        period_seconds          = 10
        failure_count_threshold = 3
      }
    }
  }

  # ── Ingress (built-in HTTPS, no separate load balancer needed) ──
  ingress {
    external_enabled = true
    target_port      = 80
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = local.common_tags

  depends_on = [
    azurerm_role_assignment.aca_acr_pull,
    azurerm_role_assignment.aca_keyvault,
  ]
}
