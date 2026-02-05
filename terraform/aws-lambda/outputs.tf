output "lambda_arn" {
  value = aws_lambda_function.ftp_to_s3.arn
}

output "lambda_function_arn" {
  description = "The ARN of the Lambda function"
  value       = aws_lambda_function.s3_to_rds_lambda.arn
}

# FTP Lambda outputs for site switching system
output "ftp_lambda_arn" {
  description = "ARN of the FTP to S3 Lambda function"
  value       = aws_lambda_function.ftp_to_s3.arn
}

output "ftp_lambda_function_name" {
  description = "Name of the FTP to S3 Lambda function"
  value       = aws_lambda_function.ftp_to_s3.function_name
}

output "s3_to_rds_lambda_arn" {
  description = "ARN of the S3 to RDS Lambda function"
  value       = aws_lambda_function.s3_to_rds_lambda.arn
}

output "s3_to_rds_lambda_function_name" {
  description = "Name of the S3 to RDS Lambda function"
  value       = aws_lambda_function.s3_to_rds_lambda.function_name
}

# Enhanced Lambda outputs
output "enhanced_ftp_lambda_arn" {
  description = "ARN of the enhanced FTP Lambda function"
  value       = aws_lambda_function.enhanced_ftp_lambda.arn
}

output "enhanced_ftp_lambda_function_name" {
  description = "Name of the enhanced FTP Lambda function"
  value       = aws_lambda_function.enhanced_ftp_lambda.function_name
}

output "sns_alarm_trigger_arn" {
  description = "ARN of the SNS alarm trigger Lambda function"
  value       = aws_lambda_function.sns_alarm_trigger.arn
}

output "sns_alarm_trigger_function_name" {
  description = "Name of the SNS alarm trigger Lambda function"
  value       = aws_lambda_function.sns_alarm_trigger.function_name
}
