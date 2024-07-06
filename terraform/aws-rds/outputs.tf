output "rds_cluster_arn" {
  value = aws_rds_cluster.rds_postgresql_cluster.arn
}

output "rds_cluster_secret_arn" {
  value = aws_secretsmanager_secret_version.rds_cluster_master_password.arn
}

output "rds_connection_string_secret_arn" {
  value = aws_secretsmanager_secret.rds_connection_string.arn
}
