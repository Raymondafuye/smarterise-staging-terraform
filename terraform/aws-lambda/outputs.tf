output "lambda_arn" {
  value = aws_lambda_function.ftp_to_s3.arn
}
output "lambda_function_arn" {
  description = "The ARN of the Lambda function"
  value       = aws_lambda_function.s3_to_rds_lambda.arn
}
