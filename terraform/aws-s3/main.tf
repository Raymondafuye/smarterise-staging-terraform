#############################
####### datalake raw ########
#############################
# Import existing S3 buckets instead of creating new ones
resource "aws_s3_bucket" "datalake_raw" {
  bucket        = var.datalake_raw_storage_bucket_name
  force_destroy = true
  
  lifecycle {
    prevent_destroy = false
    ignore_changes = [bucket]
  }
}

# Add ownership controls to enable ACLs
resource "aws_s3_bucket_ownership_controls" "datalake_raw_ownership" {
  bucket = aws_s3_bucket.datalake_raw.id
  rule {
    object_ownership = "ObjectWriter"
  }
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
  depends_on = [aws_s3_bucket_ownership_controls.datalake_raw_ownership]
  
  bucket = aws_s3_bucket.datalake_raw.id
  acl    = "private"
}


#############################
# datalake raw query results#
#############################
### s3 for athena datalake raw query results ####
### s3 for athena datalake raw query results ####
resource "aws_s3_bucket" "athena_datalake_raw_results_storage" {
  bucket        = var.datalake_raw_athena_results_storage_bucket_name
  force_destroy = true
}

# Add ownership controls to enable ACLs
resource "aws_s3_bucket_ownership_controls" "athena_datalake_raw_results_storage_ownership" {
  bucket = aws_s3_bucket.athena_datalake_raw_results_storage.id
  rule {
    object_ownership = "ObjectWriter"
  }
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
  depends_on = [aws_s3_bucket_ownership_controls.athena_datalake_raw_results_storage_ownership]
  
  bucket = aws_s3_bucket.athena_datalake_raw_results_storage.id
  acl    = "private"
}



#############################
##### IoT Cert bucket #######
#############################
resource "aws_s3_bucket" "iot_device_certificate_bucket" {
  bucket = var.iot_device_certificate_bucket_name
}

# Add ownership controls to enable ACLs
resource "aws_s3_bucket_ownership_controls" "iot_device_certificate_bucket_ownership" {
  bucket = aws_s3_bucket.iot_device_certificate_bucket.id
  rule {
    object_ownership = "ObjectWriter"
  }
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
  # Add depends_on to ensure ownership controls are applied first
  depends_on = [aws_s3_bucket_ownership_controls.iot_device_certificate_bucket_ownership]
  
  bucket = aws_s3_bucket.iot_device_certificate_bucket.id
  acl    = "private"
}


#############################
##### RDS State bucket ######
#############################

resource "aws_s3_bucket" "rds_state_bucket" {
  bucket = var.rds_state_bucket_name
}

#resource "aws_s3_bucket_server_side_encryption_configuration" "rds_state_bucket_encryption_config" {
#  bucket = aws_s3_bucket.rds_state_bucket.bucket
#  rule {
#    apply_server_side_encryption_by_default {
#      sse_algorithm = "AES256"
#    }
#  }
#}

#resource "aws_s3_bucket_acl" "rds_state_bucket_encryption_config_acl" {
#  bucket = aws_s3_bucket.rds_state_bucket.id
#  acl    = "private"
#}


#############################
### Temperature Monitoring ##
#############################
resource "aws_s3_bucket" "temperature_monitoring" {
  bucket        = var.temperature_monitoring_bucket_name
  force_destroy = false
}

resource "aws_s3_bucket_ownership_controls" "temperature_monitoring_ownership" {
  bucket = aws_s3_bucket.temperature_monitoring.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "temperature_monitoring_encryption" {
  bucket = aws_s3_bucket.temperature_monitoring.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_acl" "temperature_monitoring_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.temperature_monitoring_ownership]
  bucket     = aws_s3_bucket.temperature_monitoring.id
  acl        = "private"
}

resource "aws_s3_bucket_versioning" "temperature_monitoring_versioning" {
  bucket = aws_s3_bucket.temperature_monitoring.id
  versioning_configuration {
    status = "Enabled"
  }
}
