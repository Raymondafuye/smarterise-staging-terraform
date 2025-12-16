### s3 bucket for Web App ###
resource "aws_s3_bucket" "web_app_bucket" {
  bucket        = var.web_app_bucket_name
  force_destroy = true
}

data "aws_iam_policy_document" "cloudfront_read_s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.web_app_bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.cf_oai.iam_arn]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.web_app_bucket.arn]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.cf_oai.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "allow_cloudfront" {
  bucket = aws_s3_bucket.web_app_bucket.id
  policy = data.aws_iam_policy_document.cloudfront_read_s3_policy.json
}

resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket = aws_s3_bucket.web_app_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_s3_bucket_server_side_encryption_configuration" "web_app_bucket_encryption_config" {
  bucket = aws_s3_bucket.web_app_bucket.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_website_configuration" "web_app_bucket_website_configuration" {
  bucket = aws_s3_bucket.web_app_bucket.bucket

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_cors_configuration" "web_app_bucket_cors_config" {
  bucket = aws_s3_bucket.web_app_bucket.bucket

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "POST"]
    allowed_origins = [var.smarterise_domain_root]
    max_age_seconds = 3000
  }
}
