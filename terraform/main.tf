# ============================================================
# main.tf — Provider and backend configuration
# ============================================================
# The azurerm provider talks to the Azure Resource Manager API.
# The backend stores Terraform state in Azure Blob Storage so
# CI/CD and local runs always share the same source of truth.
# ============================================================

terraform {
  required_version = ">= 1.7"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }

  # Remote state in Azure Blob Storage.
  # Values are supplied via -backend-config flags in CI (see deploy.yml).
  backend "azurerm" {}
}

provider "azurerm" {
  features {
    key_vault {
      # Soft-delete protects secrets from accidental destruction.
      purge_soft_delete_on_destroy = false
    }
  }
}

# ── Resource Group ───────────────────────────────────────────
# Everything in Azure lives inside a resource group.
# One resource group per environment keeps billing and access clean.
resource "azurerm_resource_group" "main" {
  name     = "${var.app_name}-${var.environment}-rg"
  location = var.location

  tags = local.common_tags
}

# ── Common tags applied to every resource ───────────────────
locals {
  common_tags = {
    project     = var.app_name
    environment = var.environment
    managed_by  = "terraform"
  }
}
