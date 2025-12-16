## lambda layers
resource "aws_lambda_layer_version" "aws_wrangler" {
  filename   = "${path.module}/../../lambda/awswrangler-layer-2.16.1-py3.9.zip"
  layer_name = var.lambda_layer_aws_wrangler_name
  compatible_runtimes = ["python3.9"]
}
#rds layer
resource "aws_lambda_layer_version" "aws_pandas" {
  filename   = "${path.module}/../../lambda/python-pandas-409f5c86-0121-4a8b-b083-84238a2d672a.zip"
  layer_name = var.lambda_layer_aws_pandas_name
  compatible_runtimes = ["python3.12"]
}


resource "aws_lambda_layer_version" "flattenjson" {
  filename   = "${path.module}/../../lambda/flattenjson.zip"
  layer_name = var.lambda_layer_flattenjson_name

  compatible_runtimes = ["python3.9"]
}

resource "aws_lambda_layer_version" "sqlalchemy" {
  filename   = "${path.module}/../../lambda/sqlalchemy.zip"
  layer_name = var.lambda_layer_sqlalchemy_aurora_data_api_name
  compatible_runtimes = ["python3.12"]
  compatible_architectures = ["x86_64"] # Added compatible architectures
}

# resource "aws_lambda_layer_version" "catboost" {
#   filename   = "${path.module}/../../catboost.zip"
#   layer_name = var.lambda_layer_catboost_name

#   compatible_runtimes = ["python3.9"]
# }

module "smart_device_to_s3_raw_lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "4.0.2"
  cloudwatch_logs_retention_in_days = 3
  function_name = var.smart_device_to_s3_raw_lambda_name
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  timeout       = "900"
  layers        = [aws_lambda_layer_version.aws_wrangler.arn, aws_lambda_layer_version.flattenjson.arn]

  source_path = [
    "${path.module}/../../lambda/smart-device-to-s3-raw/lambda_function.py",
    "${path.module}/../../lambda/smart-device-to-s3-raw/config.py",
  ]
    environment_variables = merge(
    var.smart_device_to_s3_raw_lambda_function_env_vars,
    { PARSED_DEVICE_KINESIS_DATA_STREAM_NAME = var.device_kinesis_data_stream_name }
  )
  recreate_missing_package = false
  ignore_source_code_hash  = true
  create_role              = false
  lambda_role              = aws_iam_role.iam_for_lambda.arn
  memory_size              = 1024
}

resource "aws_lambda_event_source_mapping" "lambda_smart_device_to_s3_event_mapping" {
  event_source_arn                   = var.device_kinesis_data_stream_arn
  function_name                      = module.smart_device_to_s3_raw_lambda_function.lambda_function_arn
  starting_position                  = "LATEST"
  batch_size                         = 500 #different from prod
  maximum_batching_window_in_seconds = 60
  parallelization_factor             = 2
  maximum_retry_attempts             = 5
  bisect_batch_on_function_error     = true
 
}

module "smart_device_to_rds_lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "4.0.2"
  cloudwatch_logs_retention_in_days = 3

  function_name = var.smart_device_to_rds_lambda_name
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  timeout       = "600"

  layers = [
    "arn:aws:lambda:eu-west-2:794038252750:layer:python-pandas:4",
    "arn:aws:lambda:eu-west-2:794038252750:layer:sqlchemy:1"
  ]

  source_path = [
    "${path.module}/../../lambda/smart-device-to-rds/lambda_function.py",
    "${path.module}/../../lambda/smart-device-to-rds/config.py",
  ]

  environment_variables = merge(
    {
      DB_HOST     = split(":", var.rds_endpoint)[0]
      DB_NAME     = var.rds_db_name
      DB_USER     = var.rds_username
      DB_PASSWORD = var.rds_password
      DB_PORT     = "5432"
    },
    var.smart_deivce_to_rds_env_vars
  )

  recreate_missing_package = false
  ignore_source_code_hash  = true
  create_role              = false
  lambda_role              = aws_iam_role.iam_for_lambda.arn
  memory_size              = 1024
  maximum_retry_attempts   = 5
}

resource "aws_lambda_event_source_mapping" "lambda_smart_device_to_rds_event_mapping" {
  event_source_arn                   = var.parsed_device_kinesis_data_stream_arn
  function_name                      = module.smart_device_to_rds_lambda_function.lambda_function_arn
  starting_position                  = "LATEST"
  batch_size                         = 500
  maximum_batching_window_in_seconds = 60
  parallelization_factor             = 2
  bisect_batch_on_function_error     = true

}

#Lambda for ftp_invocation



resource "aws_iam_role" "lambda_role" {
  name = "ftp_to_s3_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "ftp_to_s3_lambda_policy"
  description = "Policy to allow Lambda to access S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["s3:*"]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::${var.s3_bucket}",
          "arn:aws:s3:::${var.s3_bucket}/*"
        ]
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/ftp_to_s3"
  retention_in_days = 3 # Change retention as needed
}

resource "aws_cloudwatch_log_group" "s3_to_rds_lambda_log_group" {
  name              = "/aws/lambda/s3_to_rds_lambda"
  retention_in_days = 3
}


resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "ftp_to_s3" {
  function_name    = "ftp_to_s3"
  runtime          = "python3.12"
  handler         = "lambda_function.lambda_handler"
  role            = aws_iam_role.lambda_role.arn
  filename        = "${path.module}/../../lambda/connect-to-ftp/lambda_function.zip"
  timeout         = 120

  environment {
    variables = {
      FTP_HOST   = var.ftp_host
      FTP_USER   = var.ftp_user
      FTP_PASS   = var.ftp_pass
      FTP_FOLDER = var.ftp_folder
      S3_BUCKET  = var.s3_bucket
      S3_FOLDER  = var.s3_folder
    }
  }
  
}

resource "aws_lambda_permission" "allow_eventbridge" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ftp_to_s3.function_name
  principal     = "events.amazonaws.com"
}

#Lambda for ftp_invocation on into rds

resource "aws_iam_role" "lambda_s3_to_rds_role" {
  name = "lambda_s3_to_rds_role"

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

resource "aws_iam_policy" "lambda_s3_to_rds_policy" {
  name        = "lambda_s3_to_rds_policy"
  description = "Allows Lambda to read from S3 and write to RDS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket}",
          "arn:aws:s3:::${var.s3_bucket}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds-db:connect"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_s3_to_rds_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "s3_to_rds_lambda" {
  function_name = "s3_to_rds_lambda"
  role         = aws_iam_role.lambda_s3_to_rds_role.arn
  runtime      = "python3.12"
  handler      = "lambda_function.lambda_handler"
  filename     = "${path.module}/../../lambda/connect-ftp-to-rds/lambda_function.zip"

  environment {
    variables = merge(
      {
        DB_HOST     = split(":", var.rds_endpoint)[0]
        DB_NAME     = var.rds_db_name
        DB_USER     = var.rds_username
        DB_PASSWORD = var.rds_password
        DB_PORT     = "5432"
      },
      var.smart_deivce_to_rds_env_vars
    )
  }
  
  layers = [
    "arn:aws:lambda:eu-west-2:794038252750:layer:python-pandas:4",
    "arn:aws:lambda:eu-west-2:794038252750:layer:sqlchemy:1"
  ]

  memory_size = 256
  timeout     = 300  # 5 minutes
}

# This should be a separate resource outside the lambda function
resource "aws_s3_bucket_notification" "s3_trigger" {
  bucket = var.s3_bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_to_rds_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".csv"
  }

  depends_on = [aws_lambda_function.s3_to_rds_lambda]
}

# This should also be a separate resource
resource "aws_lambda_permission" "allow_s3_trigger" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_to_rds_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.s3_bucket}"
}



#module "invoke_ml_model" {
#  source  = "terraform-aws-modules/lambda/aws"
#  version = "4.0.2"

#  function_name = "invoke-ml-model"
#  handler       = "lambda_function.lambda_handler"
#  runtime       = "python3.9"
#  timeout       = "600"
#  layers        = [aws_lambda_layer_version.aws_wrangler.arn] #aws_lambda_layer_version.catboost.arn]

#  source_path = [
#    "${path.module}/../../lambda/invoke-ml-model/lambda_function.py",
#    # "${path.module}/../../lambda/invoke-ml-model/apapa_model",
#  ]

#  recreate_missing_package = false
#  ignore_source_code_hash  = true
#  create_role              = false
#  lambda_role              = aws_iam_role.iam_for_lambda.arn
#  memory_size              = 1024
#  maximum_retry_attempts   = 5
#}

#resource "aws_lambda_event_source_mapping" "lambda_invoke_ml_model_event_mapping" {
#  event_source_arn                   = var.parsed_device_kinesis_data_stream_arn
#  function_name                      = module.invoke_ml_model.lambda_function_arn
#  starting_position                  = "LATEST"
#  batch_size                         = 1000
#  maximum_batching_window_in_seconds = 60
#  parallelization_factor             = 5
#  bisect_batch_on_function_error     = true

#}


### Connect to Aurora ###
# designed to stop Aurora from stopping and restoring from a snapshot, instead keeping it paused at 0 ACUs

#module "connect_to_aurora" {
#  source  = "terraform-aws-modules/lambda/aws"
#  version = "4.0.2"

#  function_name = "connect-to-aurora"
#  handler       = "lambda_function.lambda_handler"
#  runtime       = "python3.9"
#  timeout       = "600"
#  layers        = [aws_lambda_layer_version.sqlalchemy.arn] #aws_lambda_layer_version.catboost.arn]

#  source_path = [
#    "${path.module}/../../lambda/connect-to-aurora/lambda_function.py",
#  ]

#  environment_variables    = var.connect_to_aurora_lambda_function_env_vars
#  recreate_missing_package = false
#  ignore_source_code_hash  = true
#  create_role              = false
#  lambda_role              = aws_iam_role.iam_for_lambda.arn
#  memory_size              = 128
#  maximum_retry_attempts   = 5
#}


#resource "aws_cloudwatch_event_rule" "schedule_connect_to_aurora" {
#  name                = var.schedule_connect_to_aurora_name
#  description         = "Schedule Lambda function execution for connect to aurora lambda"
#  schedule_expression = "cron(00 23 */6 * ? *)"
#  state = "ENABLED" 
#}


#resource "aws_cloudwatch_event_target" "connect_to_aurora_lambda_execution" {
#  arn  = module.connect_to_aurora.lambda_function_arn
#  rule = aws_cloudwatch_event_rule.schedule_connect_to_aurora.name
#}

###########################################################
# AWS Lambda Trigger
###########################################################
#resource "aws_lambda_permission" "connect_to_aurora_allow_cloudwatch_event_rule" {
#  statement_id  = "AllowExecutionFromCloudWatch"
#  action        = "lambda:InvokeFunction"
#  function_name = module.connect_to_aurora.lambda_function_arn
#  principal     = "events.amazonaws.com"
#  source_arn    = aws_cloudwatch_event_rule.schedule_connect_to_aurora.arn
#}
