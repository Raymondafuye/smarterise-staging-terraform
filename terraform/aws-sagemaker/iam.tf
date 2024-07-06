data "aws_iam_policy_document" "iam_policy_document" {
  statement {
    sid = ""
    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload",
      "s3:CreateBucket",
      "s3:PutObject",
      "s3:PutBucketPublicAccessBlock"
    ]
    effect = "Allow"
    resources = [
      var.datalake_raw_bucket_arn,
      "${var.datalake_raw_bucket_arn}/*",
      var.datalake_raw_athena_results_bucket_arn,
      "${var.datalake_raw_athena_results_bucket_arn}/*",
    ]
  }
  statement {
    sid = ""
    actions = [
      "athena:BatchGetQueryExecution",
      "athena:CancelQueryExecution",
      "athena:GetCatalogs",
      "athena:GetExecutionEngine",
      "athena:GetExecutionEngines",
      "athena:GetNamespace",
      "athena:GetNamespaces",
      "athena:GetQueryExecution",
      "athena:GetQueryExecutions",
      "athena:GetQueryResults",
      "athena:GetQueryResultsStream",
      "athena:GetTable",
      "athena:GetTables",
      "athena:ListQueryExecutions",
      "athena:RunQuery",
      "athena:StartQueryExecution",
      "athena:StopQueryExecution",
      "athena:ListWorkGroups",
      "athena:ListEngineVersions",
      "athena:GetWorkGroup",
      "athena:GetDataCatalog",
      "athena:GetDatabase",
      "athena:GetTableMetadata",
      "athena:ListDataCatalogs",
      "athena:ListDatabases",
      "athena:ListTableMetadata",
      "glue:*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}


resource "aws_iam_role" "sagemaker_iam_role" {
  name = "sagemaker_iam_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = [
            "sagemaker.amazonaws.com"
          ],
        }
      },
    ]
  })
}


resource "aws_iam_role_policy_attachment" "sagemaker_iam_policy_attachment" {
  role       = aws_iam_role.sagemaker_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

resource "aws_iam_role_policy_attachment" "iam_role_policy_attachment" {
  role       = aws_iam_role.sagemaker_iam_role.name
  policy_arn = aws_iam_policy.iam_policy.arn
}


resource "aws_iam_policy" "iam_policy" {
  name   = "datalake-sagemaker-iam-policy"
  path   = "/"
  policy = data.aws_iam_policy_document.iam_policy_document.json
}

