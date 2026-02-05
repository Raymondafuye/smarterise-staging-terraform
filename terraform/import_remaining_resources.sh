#!/bin/bash

# Import Missing Resources Script
# Only imports resources not already in Terraform state

echo "🔄 Importing remaining AWS resources..."

# Check if resource exists in state before importing
import_if_missing() {
    local resource_address="$1"
    local resource_id="$2"
    
    if ! terraform state show "$resource_address" &>/dev/null; then
        echo "📦 Importing $resource_address..."
        terraform import "$resource_address" "$resource_id"
    else
        echo "✅ $resource_address already in state"
    fi
}

# Import S3 buckets (check if missing)
import_if_missing "module.s3.aws_s3_bucket.datalake_raw" "smarterise-datalake-raw-dev1"
import_if_missing "module.s3.aws_s3_bucket.athena_datalake_raw_results_storage" "datalake-raw-athena-results1"
import_if_missing "module.s3.aws_s3_bucket.iot_device_certificate_bucket" "smarterise-accuenergy-mqtt-certificates1"
import_if_missing "module.s3.aws_s3_bucket.rds_state_bucket" "smarterise-rds-state1"
import_if_missing "module.web-app.aws_s3_bucket.web_app_bucket" "smarterise-web-app-dev-dev"

# Import RDS credentials (check if missing)
import_if_missing "module.rds.aws_secretsmanager_secret.rds_credentials" "rds-credentials-postgresql-instance"
import_if_missing "module.rds.aws_secretsmanager_secret.rds_connection_string" "rds-connection-string-postgresql-instance"

# Import RDS instance (if exists)
import_if_missing "module.rds.aws_db_instance.postgresql_instance" "postgresql-instance"

# Import Kinesis stream (if exists)
import_if_missing "module.aws_kinesis_data_stream.aws_kinesis_stream.smart_device_stream" "smart-device-stream"

# Import Lambda functions (if they exist)
import_if_missing "module.aws-lambda.aws_lambda_function.smart_device_kinesis_to_s3" "smart-device-kinesis-to-s3"
import_if_missing "module.aws-lambda.aws_lambda_function.smart_device_to_rds" "smart-device-to-rds"
import_if_missing "module.aws-lambda.aws_lambda_function.ftp_to_s3" "ftp_to_s3"
import_if_missing "module.aws-lambda.aws_lambda_function.s3_to_rds_lambda" "s3_to_rds_lambda"
import_if_missing "module.aws-lambda.aws_lambda_function.enhanced_ftp_processor" "enhanced-ftp-processor"
import_if_missing "module.aws-lambda.aws_lambda_function.SNS_Alarm_Message_Trigger" "SNS_Alarm_Message_Trigger"

# Import site config resources
import_if_missing "module.aws-site-config.aws_s3_bucket.site_config_bucket" "smarterise-site-config"
import_if_missing "module.aws-site-config.aws_lambda_function.site_config_manager" "site-config-manager"

# Import ALB (if exists)
import_if_missing "module.aws-ecs.aws_lb.api_service_alb" "arn:aws:elasticloadbalancing:eu-west-2:794038252750:loadbalancer/app/api-load-balancer/e3be1004c7f37697"

# Import ECS resources (if they exist)
import_if_missing "module.aws-ecs.aws_ecs_cluster.api_service_cluster" "api_service_cluster"
import_if_missing "module.aws-ecs.aws_ecs_service.api_service" "api_service"

echo "✅ Import complete! All existing resources are now in Terraform state."
echo ""
echo "🎯 Next steps:"
echo "   1. Run 'terraform plan' to see what needs to be created"
echo "   2. Run 'terraform apply' to create missing resources"