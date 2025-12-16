output "rds_instance_endpoint" {
  value = aws_db_instance.rds_postgresql.endpoint
}

output "rds_instance_arn" {
  value = aws_db_instance.rds_postgresql.arn
}

output "rds_instance_name" {
  value = aws_db_instance.rds_postgresql.db_name
}

output "rds_instance_username" {
  value = aws_db_instance.rds_postgresql.username
}

output "rds_credentials_secret_arn" {
  value = aws_secretsmanager_secret.rds_credentials.arn
}

output "rds_connection_string_secret_arn" {
  value = aws_secretsmanager_secret.rds_connection_string.arn
}

output "rds_instance_password" {
  value     = random_password.master.result
  sensitive = true
}
