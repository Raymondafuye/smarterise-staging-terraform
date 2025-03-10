## datalake IAM policy

data "aws_iam_policy_document" "iam_policy_document" {

  statement {
    sid     = ""
    actions = ["s3:*"]
    effect  = "Allow"
    resources = [
      var.datalake_raw_bucket_arn,
      "${var.datalake_raw_bucket_arn}/*",
      var.datalake_raw_athena_results_bucket_arn,
      "${var.datalake_raw_athena_results_bucket_arn}/*",
    ]
  }

  statement {
    sid       = ""
    actions   = ["athena:*"]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    sid = ""
    actions = [
      "glue:CreateDatabase",
      "glue:DeleteDatabase",
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:UpdateDatabase",
      "glue:CreateTable",
      "glue:DeleteTable",
      "glue:BatchDeleteTable",
      "glue:UpdateTable",
      "glue:GetTable",
      "glue:GetTables",
      "glue:BatchCreatePartition",
      "glue:CreatePartition",
      "glue:DeletePartition",
      "glue:BatchDeletePartition",
      "glue:UpdatePartition",
      "glue:GetPartition",
      "glue:GetPartitions",
      "glue:BatchGetPartition"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
  statement {
    sid = ""
    actions = [
      "kinesis:DescribeStream",
      "kinesis:PutRecord",
      "kinesis:DescribeStreamSummary",
      "kinesis:GetRecords",
      "kinesis:GetShardIterator",
      "kinesis:ListShards",
      "kinesis:ListStreams",
      "kinesis:SubscribeToShard"
    ]
    effect = "Allow"
    resources = [
      var.device_kinesis_data_stream_arn,
    ]
  }
  statement {
    sid = ""
    actions = [
      "kinesis:PutRecord",
      "kinesis:PutRecords",
      "kinesis:GetRecords",
      "kinesis:GetShardIterator",
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:ListShards",
      "kinesis:ListStreams",
      "kinesis:SubscribeToShard",
    ]
    effect = "Allow"
    resources = [
      var.parsed_device_kinesis_data_stream_arn,
    ]
  }
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
  statement {
    sid = ""
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    effect = "Allow"
    resources = [
      var.rds_credentials_secret_arn
    ]
  }
  statement {
    sid = ""
    actions = [
      "logs:DescribeLogGroups",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    sid = ""
    actions = [
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeInstances",
      "ec2:AttachNetworkInterface"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    sid = ""
    actions = [
      "glue:GetTable"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    sid = ""
    actions = [
      "ecr:*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

}

resource "aws_iam_policy" "iam_policy" {
  name   = "datalake-lambda-iam-policy"
  path   = "/"
  policy = data.aws_iam_policy_document.iam_policy_document.json
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "data_lake_iam_for_lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = [
            "lambda.amazonaws.com"
          ],
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "iam_role_policy_attachment" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.iam_policy.arn
}
