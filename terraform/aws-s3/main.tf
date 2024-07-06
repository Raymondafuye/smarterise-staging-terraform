#############################
####### datalake raw ########
#############################
resource "aws_s3_bucket" "datalake_raw" {
  bucket        = var.datalake_raw_storage_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "datalake_raw_encryption_config" {
  bucket = aws_s3_bucket.datalake_raw.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_acl" "datalake_raw_acl" {
  bucket = aws_s3_bucket.datalake_raw.id
  acl    = "private"
}

#############################
# datalake raw query results#
#############################
### s3 for athena datalake raw query results ####
resource "aws_s3_bucket" "athena_datalake_raw_results_storage" {
  bucket        = var.datalake_raw_athena_results_storage_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_datalake_raw_results_storage_encryption" {
  bucket = aws_s3_bucket.athena_datalake_raw_results_storage.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_acl" "athena_datalake_raw_results_storage_acl" {
  bucket = aws_s3_bucket.athena_datalake_raw_results_storage.id
  acl    = "private"
}

#############################
##### IoT Cert bucket #######
#############################
resource "aws_s3_bucket" "iot_device_certificate_bucket" {
  bucket = var.iot_device_certificate_bucket_name
}

resource "aws_s3_bucket_server_side_encryption_configuration" "iot_device_certificate_bucket_encryption_config" {
  bucket = aws_s3_bucket.iot_device_certificate_bucket.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_acl" "iot_device_certificate_bucket_encryption_config_acl" {
  bucket = aws_s3_bucket.iot_device_certificate_bucket.id
  acl    = "private"
}

#############################
##### RDS State bucket ######
#############################

resource "aws_s3_bucket" "rds_state_bucket" {
  bucket = var.rds_state_bucket_name
}

resource "aws_s3_bucket_server_side_encryption_configuration" "rds_state_bucket_encryption_config" {
  bucket = aws_s3_bucket.rds_state_bucket.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_acl" "rds_state_bucket_encryption_config_acl" {
  bucket = aws_s3_bucket.rds_state_bucket.id
  acl    = "private"
}
