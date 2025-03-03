# This module has the ECS services and cluster

# Prepare logs
resource "aws_cloudwatch_log_group" "platform_logs" {
  name              = "platform_logs_${lower(var.environment)}"
  retention_in_days = var.log_retention_in_days
}

# Prepare ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "main_${lower(var.environment)}"


  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.platform_logs.name
      }
    }
  }
}

data "aws_iam_policy_document" "ecs_task_execution_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecsTaskExecutionRole${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Add policy to allow reading secrets from secrets manager
resource "aws_iam_policy" "secrets_readonly" {
  name        = "secrets_manager_readonly"
  path        = "/"
  description = "Allow ecs role to read secrets"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [
      {
        "Effect" = "Allow",
        "Action" = [
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ],
        "Resource" : "arn:aws:secretsmanager:${var.region}:${var.aws_account_id}:secret:*"
      },
      {
        "Effect" : "Allow",
        "Action" : "secretsmanager:ListSecrets",
        "Resource" : "*"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "secrets_readonly" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.secrets_readonly.arn
}

data "aws_iam_policy_document" "rds_data_api_iam_policy_document" {
  statement {
    sid = ""
    actions = [
      "rds-data:BeginTransaction",
      "rds-data:ExecuteStatement",
      "rds-data:BatchExecuteStatement",
      "rds-data:CommitTransaction",
      "rds-data:RollbackTransaction"
    ]
    effect = "Allow"
    resources = [
      var.rds_instance_arn
    ]
  }
}

resource "aws_iam_policy" "rds_data_iam_policy" {
  name   = "rds_data_iam_policy"
  path   = "/"
  policy = data.aws_iam_policy_document.rds_data_api_iam_policy_document.json
}

resource "aws_iam_role_policy_attachment" "rds_data_iam_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.rds_data_iam_policy.arn
}
