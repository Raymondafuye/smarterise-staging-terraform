resource "aws_secretsmanager_secret" "rds_credentials" {
  name = "rds-credentials-${aws_db_instance.rds_postgresql.identifier}"
}

resource "aws_secretsmanager_secret_version" "rds_instance_master_password" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = aws_db_instance.rds_postgresql.username
    password = random_password.master.result
    engine   = "postgres"
    host     = aws_db_instance.rds_postgresql.endpoint
  })
}

resource "aws_secretsmanager_secret" "rds_connection_string" {
  name = "rds-connection-string-${aws_db_instance.rds_postgresql.identifier}"
}

resource "aws_secretsmanager_secret_version" "rds_connection_string_secret_version" {
  secret_id = aws_secretsmanager_secret.rds_connection_string.id
  secret_string = jsonencode({
    connection_string = "postgres://${aws_db_instance.rds_postgresql.username}:${random_password.master.result}@${aws_db_instance.rds_postgresql.endpoint}/${aws_db_instance.rds_postgresql.db_name}"
  })
}
