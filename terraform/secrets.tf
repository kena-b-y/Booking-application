resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.app_name}/db-password"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}

resource "aws_secretsmanager_secret" "app_key" {
  name = "${var.app_name}/app-key"
}
# Set app_key secret value manually once, or via a data source