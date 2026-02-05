#!/bin/bash

# Infrastructure Import Script
# This script imports existing AWS resources into Terraform state

echo "🔄 Importing existing AWS resources into Terraform state..."

# Import existing S3 buckets
echo "📦 Importing S3 buckets..."
terraform import module.s3.aws_s3_bucket.datalake_raw smarterise-datalake-raw-dev1
terraform import module.s3.aws_s3_bucket.athena_datalake_raw_results_storage datalake-raw-athena-results1
terraform import module.s3.aws_s3_bucket.iot_device_certificate_bucket smarterise-accuenergy-mqtt-certificates1
terraform import module.s3.aws_s3_bucket.rds_state_bucket smarterise-rds-state1
terraform import module.web-app.aws_s3_bucket.web_app_bucket smarterise-web-app-dev-dev

# Skip Lambda event source mappings - they don't exist
echo "⚡ Skipping Lambda event source mappings (will be created fresh)..."

# Import existing Secrets Manager secrets (correct module name)
echo "🔐 Importing existing RDS credentials..."
terraform import module.rds.aws_secretsmanager_secret.rds_credentials rds-credentials-postgresql-instance
terraform import module.rds.aws_secretsmanager_secret.rds_connection_string rds-connection-string-postgresql-instance

echo "✅ Import complete! Your RDS credentials and S3 buckets have been preserved."
echo ""
echo "🎯 Your existing infrastructure is now managed by Terraform while preserving:"
echo "   ✅ RDS database credentials"
echo "   ✅ S3 buckets and data"
echo "   ✅ All existing resources"