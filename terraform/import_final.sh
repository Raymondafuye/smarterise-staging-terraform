#!/bin/bash

# Final Import Script - Only Resources That Exist in Terraform Config
# Based on actual main.tf structure and AWS discovery

echo "🔄 Importing resources that match Terraform configuration..."

# Function to import if resource exists in state
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

# Import S3 buckets (these match the module structure)
echo "📦 Importing S3 buckets..."
import_if_missing "module.s3.aws_s3_bucket.datalake_raw" "smarterise-datalake-raw-dev1"
import_if_missing "module.s3.aws_s3_bucket.athena_datalake_raw_results_storage" "datalake-raw-athena-results1"
import_if_missing "module.s3.aws_s3_bucket.iot_device_certificate_bucket" "smarterise-accuenergy-mqtt-certificates1"
import_if_missing "module.s3.aws_s3_bucket.rds_state_bucket" "smarterise-rds-state1"
import_if_missing "module.web-app.aws_s3_bucket.web_app_bucket" "smarterise-web-app-dev-dev"
import_if_missing "module.aws-site-config.aws_s3_bucket.site_config_bucket" "smarterise-site-config"

# Import RDS resources (these match the rds module)
echo "🗄️ Importing RDS resources..."
import_if_missing "module.rds.aws_db_instance.rds_postgresql" "postgresql-instance"
import_if_missing "module.rds.aws_secretsmanager_secret.rds_credentials" "rds-credentials-postgresql-instance"
import_if_missing "module.rds.aws_secretsmanager_secret.rds_connection_string" "rds-connection-string-postgresql-instance"

# Import Kinesis stream (matches aws_kinesis_data_stream module)
echo "🌊 Importing Kinesis stream..."
import_if_missing "module.aws_kinesis_data_stream.aws_kinesis_stream.device_data_stream" "device-data-stream"

# Import Route53 hosted zone (matches aws-route53 module)
echo "🌐 Importing Route53 hosted zone..."
import_if_missing "module.aws-route53.aws_route53_zone.root_dns_zone" "Z04381603GG9QI2N43P57"

# Skip Lambda functions - they use complex module structure that's already managed
echo "⚡ Skipping Lambda functions - using existing module structure..."

# Skip ALB and ECS - they use complex module structure that's already managed  
echo "⚖️ Skipping ALB and ECS - using existing module structure..."

echo ""
echo "✅ Import complete for resources matching Terraform configuration!"
echo ""
echo "🎯 Next steps:"
echo "   1. Run 'terraform plan' to see what needs to be created"
echo "   2. Run 'terraform apply' to sync everything"
echo ""
echo "📝 Note: Lambda, ALB, and ECS resources use complex module structures"
echo "   that are already managed by Terraform modules."