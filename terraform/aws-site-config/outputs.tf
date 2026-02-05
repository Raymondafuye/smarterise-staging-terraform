output "site_config_bucket_name" {
  description = "Name of the site configuration bucket"
  value       = aws_s3_bucket.site_config_bucket.bucket
}

output "site_config_bucket_arn" {
  description = "ARN of the site configuration bucket"
  value       = aws_s3_bucket.site_config_bucket.arn
}

output "site_config_manager_function_name" {
  description = "Name of the site config manager Lambda function"
  value       = aws_lambda_function.site_config_manager.function_name
}

output "site_config_manager_function_arn" {
  description = "ARN of the site config manager Lambda function"
  value       = aws_lambda_function.site_config_manager.arn
}