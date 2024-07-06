resource "aws_db_subnet_group" "rds_subnet_group" {
  subnet_ids = var.private_subnets
}

resource "aws_rds_cluster" "rds_postgresql_cluster" {
  cluster_identifier      = "rds-postgresql-cluster"
  db_subnet_group_name    = aws_db_subnet_group.rds_subnet_group.name
  engine                  = "aurora-postgresql"
  engine_mode             = "serverless"
  engine_version          = "11.16"
  database_name           = "smartmeters"
  master_username         = var.rds_postgresql_cluster_username
  master_password         = jsondecode(aws_secretsmanager_secret_version.rds_cluster_master_password.secret_string)["password"]
  backup_retention_period = 7
  storage_encrypted       = true
  enable_http_endpoint    = true
  skip_final_snapshot     = true
  apply_immediately       = true

  scaling_configuration {
    auto_pause               = true
    max_capacity             = 64
    min_capacity             = 4
    seconds_until_auto_pause = 300
    timeout_action           = "ForceApplyCapacityChange"
  }
  vpc_security_group_ids = [aws_security_group.rds_security_group.id]
}
