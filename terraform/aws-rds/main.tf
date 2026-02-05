resource "random_password" "master" {
  length  = 16
  special = true
  # Exclude invalid characters for RDS passwords
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_instance" "rds_postgresql" {
  identifier           = "postgresql-instance"
  engine              = "postgres"
  engine_version      = "14"
  instance_class      = "db.t3.small"
  allocated_storage   = 100
  storage_type        = "gp3"
  
  db_name             = "mydb"
  username            = var.rds_postgresql_username
  password            = random_password.master.result
  
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  skip_final_snapshot = true
  publicly_accessible = true
  apply_immediately  = true   # To apply changes immediately
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "Mon:04:00-Mon:05:00"
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group-new"
  subnet_ids = var.public_subnets
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
