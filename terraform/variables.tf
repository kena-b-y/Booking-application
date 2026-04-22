variable "aws_region"   { default = "us-east-1" }
variable "app_name"     { default = "laravel-booking" }
variable "image_tag"    { description = "Docker image tag (git SHA)" }
variable "db_password"  { sensitive = true }
variable "db_username"  { default = "laravel" }
variable "db_name"      { default = "bookings" }