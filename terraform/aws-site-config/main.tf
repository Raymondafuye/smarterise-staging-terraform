# Site Configuration Management Module
# This module manages the centralized site switching system

resource "aws_s3_bucket" "site_config_bucket" {
  bucket        = var.site_config_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "site_config_encryption" {
  bucket = aws_s3_bucket.site_config_bucket.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "site_config_versioning" {
  bucket = aws_s3_bucket.site_config_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Initial site configuration file
resource "aws_s3_object" "site_tiers_config" {
  bucket = aws_s3_bucket.site_config_bucket.bucket
  key    = "site-tiers.json"
  content = jsonencode({
    version = "1.0"
    sites = {
      for device in var.smart_device_names : device => {
        asset_id = "C${substr(device, -3, 3)}"
        tier     = "CRITICAL"
        enabled  = true
      }
    }
  })
  content_type = "application/json"
  
  lifecycle {
    ignore_changes = [content]
  }
}

# IAM role for site config manager Lambda
resource "aws_iam_role" "site_config_manager_role" {
  name = "site-config-manager-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "site_config_manager_policy" {
  name = "site-config-manager-policy"
  role = aws_iam_role.site_config_manager_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.site_config_bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.site_config_bucket.arn
      }
    ]
  })
}

# CloudWatch Log Group for Site Config Manager
resource "aws_cloudwatch_log_group" "site_config_manager_logs" {
  name              = "/aws/lambda/site-config-manager"
  retention_in_days = 3
}

# Site Config Manager Lambda
resource "aws_lambda_function" "site_config_manager" {
  filename         = data.archive_file.site_config_manager_zip.output_path
  function_name    = "site-config-manager"
  role            = aws_iam_role.site_config_manager_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 60
  source_code_hash = data.archive_file.site_config_manager_zip.output_base64sha256
  
  environment {
    variables = {
      SITE_CONFIG_BUCKET = var.site_config_bucket_name
    }
  }
  
  depends_on = [aws_cloudwatch_log_group.site_config_manager_logs]
}

data "archive_file" "site_config_manager_zip" {
  type        = "zip"
  output_path = "${path.module}/site_config_manager.zip"
  source {
    content = templatefile("${path.module}/site_config_manager.py", {
      bucket_name = var.site_config_bucket_name
    })
    filename = "lambda_function.py"
  }
}

# IoT Rule Manager Lambda
resource "aws_iam_role" "iot_rule_manager_role" {
  name = "iot-rule-manager-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "iot_rule_manager_policy" {
  name = "iot-rule-manager-policy"
  role = aws_iam_role.iot_rule_manager_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.site_config_bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "iot:ListTopicRules",
          "iot:CreateTopicRule",
          "iot:DeleteTopicRule",
          "iot:GetTopicRule"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = var.iot_kinesis_role_arn
      }
    ]
  })
}

resource "aws_lambda_function" "iot_rule_manager" {
  filename         = data.archive_file.iot_rule_manager_zip.output_path
  function_name    = "iot-rule-manager"
  role            = aws_iam_role.iot_rule_manager_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 60
  source_code_hash = data.archive_file.iot_rule_manager_zip.output_base64sha256
  
  environment {
    variables = {
      SITE_CONFIG_BUCKET      = var.site_config_bucket_name
      DEVICE_DATA_STREAM_NAME = var.device_data_stream_name
      IOT_ROLE_ARN           = var.iot_kinesis_role_arn
    }
  }
}

data "archive_file" "iot_rule_manager_zip" {
  type        = "zip"
  output_path = "${path.module}/iot_rule_manager.zip"
  source {
    content  = file("${path.module}/iot_rule_manager.py")
    filename = "lambda_function.py"
  }
}

# S3 event notification to trigger IoT rule sync
resource "aws_s3_bucket_notification" "site_config_update" {
  bucket = aws_s3_bucket.site_config_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.iot_rule_manager.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "site-tiers.json"
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke_iot_manager]
}

resource "aws_lambda_permission" "allow_s3_invoke_iot_manager" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.iot_rule_manager.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.site_config_bucket.arn
}