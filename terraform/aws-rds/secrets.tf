resource "random_password" "master" {
  length           = 16
  special          = true
  override_special = "_!%^"
}

resource "aws_secretsmanager_secret" "rds_cluster_master_password" {
  name = "rds-cluster-master-password"
}

resource "aws_secretsmanager_secret_version" "rds_cluster_master_password" {
  secret_id = aws_secretsmanager_secret.rds_cluster_master_password.id
  secret_string = jsonencode(
    {
      username = var.rds_postgresql_cluster_username
      password = random_password.master.result
    }
  )
}

resource "aws_secretsmanager_secret" "rds_connection_string" {
  name = "rds-connection-string"
}

resource "aws_secretsmanager_secret_version" "rds_connection_string_secret_version" {
  secret_id = aws_secretsmanager_secret.rds_connection_string.id
  secret_string = jsonencode(
    {
      connection_string = "postgres://${aws_rds_cluster.rds_postgresql_cluster.master_username}:${aws_rds_cluster.rds_postgresql_cluster.master_password}@${aws_rds_cluster.rds_postgresql_cluster.endpoint}/${aws_rds_cluster.rds_postgresql_cluster.database_name}"
    }
  )
}
