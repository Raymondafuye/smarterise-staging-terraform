output "iot_device_certificate_bucket_name" {
  value = aws_s3_bucket.iot_device_certificate_bucket.bucket
}

output "datalake_raw_bucket_name" {
  value = aws_s3_bucket.datalake_raw.bucket
}

output "datalake_raw_bucket_arn" {
  value = aws_s3_bucket.datalake_raw.arn
}

output "datalake_raw_athena_results_bucket_name" {
  value = aws_s3_bucket.athena_datalake_raw_results_storage.bucket
}

output "datalake_raw_athena_results_bucket_arn" {
  value = aws_s3_bucket.athena_datalake_raw_results_storage.arn
}
 