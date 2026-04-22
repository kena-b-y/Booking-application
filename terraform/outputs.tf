output "alb_dns_name" {
  description = "Public URL for the app"
  value       = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "rds_endpoint" {
  value     = aws_db_instance.main.address
  sensitive = true
}