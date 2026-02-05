# Infrastructure Outputs

# Site Switching System Outputs
output "site_config_bucket_name" {
  description = "Name of the site configuration bucket"
  value       = module.aws-site-config.site_config_bucket_name
}

output "site_config_manager_function_name" {
  description = "Name of the site config manager Lambda function"
  value       = module.aws-site-config.site_config_manager_function_name
}

# Lambda Function Outputs
output "ftp_lambda_arn" {
  description = "ARN of the FTP Lambda function"
  value       = module.aws-lambda.ftp_lambda_arn
}

output "s3_to_rds_lambda_arn" {
  description = "ARN of the S3 to RDS Lambda function"
  value       = module.aws-lambda.s3_to_rds_lambda_arn
}

# Infrastructure Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.aws-vpc.vpc_id
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.rds_instance_endpoint
  sensitive   = true
}

output "kinesis_stream_name" {
  description = "Name of the Kinesis data stream"
  value       = module.aws_kinesis_data_stream.device_data_stream_name
}

# S3 Bucket Outputs
output "datalake_bucket_name" {
  description = "Name of the datalake S3 bucket"
  value       = module.s3.datalake_raw_bucket_name
}

output "iot_certificate_bucket_name" {
  description = "Name of the IoT certificate S3 bucket"
  value       = module.s3.iot_device_certificate_bucket_name
}

# Domain and DNS Outputs
output "smarterise_domain" {
  description = "Smarterise domain root"
  value       = var.smarterise_domain_root
}

output "dns_zone_id" {
  description = "Route53 DNS zone ID"
  value       = module.aws-route53.smarterise_demo_dns_zone_id
}

# ECR Repository Output
output "api_ecr_repository_name" {
  description = "Name of the API ECR repository"
  value       = module.aws-ecr.smarterise_api_ecr_repository_name
}

# Site Switching Instructions
output "site_switching_instructions" {
  description = "Instructions for using the site switching system"
  value = <<-EOT
    🚀 Site Switching System Deployed Successfully!
    
    📋 To switch a site between CRITICAL and NON_CRITICAL tiers:
    
    1️⃣ Download current configuration:
       aws s3 cp s3://${module.aws-site-config.site_config_bucket_name}/site-tiers.json .
    
    2️⃣ Edit the JSON file to change the tier:
       - "tier": "CRITICAL" (real-time IoT + daily FTP backup)
       - "tier": "NON_CRITICAL" (FTP-only monitoring, hourly sync)
    
    3️⃣ Upload updated configuration:
       aws s3 cp site-tiers.json s3://${module.aws-site-config.site_config_bucket_name}/
    
    4️⃣ Changes take effect within 5 minutes
    
    🔧 Site Config Manager Function: ${module.aws-site-config.site_config_manager_function_name}
    
    📊 Tier Definitions:
    - CRITICAL: Real-time IoT processing + daily FTP backup at 11 PM
    - NON_CRITICAL: FTP-only monitoring with hourly sync + CloudWatch metrics
    
    🌐 Application URL: https://${var.smarterise_domain_root}
  EOT
}