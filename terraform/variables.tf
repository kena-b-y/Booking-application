# ============================================================
# variables.tf — All input variables in one place
# ============================================================
# Sensitive variables (db_password, app_key) are marked
# sensitive = true so Terraform never prints them in logs.
# ============================================================

variable "app_name" {
  description = "Base name used as a prefix on all Azure resources"
  type        = string
  default     = "laravel-booking"
}

variable "environment" {
  description = "Deployment environment — dev, staging, or production"
  type        = string
  default     = "production"
}

variable "location" {
  description = "Azure region to deploy into"
  type        = string
  default     = "East US"
}

variable "image_tag" {
  description = "Docker image tag (git commit SHA) to deploy"
  type        = string
}

variable "db_admin_username" {
  description = "MySQL administrator username"
  type        = string
  default     = "laraveladmin"
}

variable "db_password" {
  description = "MySQL administrator password — supplied via CI secret, never hardcoded"
  type        = string
  sensitive   = true
}

variable "app_key" {
  description = "Laravel APP_KEY — supplied via CI secret, never hardcoded"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Name of the MySQL database"
  type        = string
  default     = "booking_db"
}

variable "container_cpu" {
  description = "CPU allocation for the container app (0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0)"
  type        = number
  default     = 0.5
}

variable "container_memory" {
  description = "Memory allocation for the container app in Gi (must match allowed CPU/memory combinations)"
  type        = string
  default     = "1Gi"
}

variable "min_replicas" {
  description = "Minimum number of container replicas (0 = scale to zero when idle)"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum number of container replicas under load"
  type        = number
  default     = 5
}
