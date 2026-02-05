#!/bin/bash

# Infrastructure Import Script - Corrected Version
# This script imports existing AWS resources into Terraform state

echo "🔄 Importing existing AWS resources into Terraform state..."

# Import existing S3 buckets
echo "📦 Importing S3 buckets..."
terraform import module.s3.aws_s3_bucket.datalake_raw smarterise-datalake-raw-dev1
terraform import module.s3.aws_s3_bucket.athena_datalake_raw_results_storage datalake-raw-athena-results1
terraform import module.s3.aws_s3_bucket.iot_device_certificate_bucket smarterise-accuenergy-mqtt-certificates1
terraform import module.s3.aws_s3_bucket.rds_state_bucket smarterise-rds-state1
terraform import module.web-app.aws_s3_bucket.web_app_bucket smarterise-web-app-dev-dev

# Import existing Route53 hosted zone
echo "🌐 Importing Route53 hosted zone..."
terraform import module.aws-ecs.aws_route53_zone.smarterise_dns_zone Z04381603GG9QI2N43P57

# Import existing RDS credentials (correct module name)
echo "🔐 Importing existing RDS credentials..."
terraform import module.rds.aws_secretsmanager_secret.rds_credentials rds-credentials-postgresql-instance
terraform import module.rds.aws_secretsmanager_secret.rds_connection_string rds-connection-string-postgresql-instance

# Import existing ACM certificate
echo "🔒 Importing existing ACM certificate..."
terraform import module.aws-ecs.aws_acm_certificate.ssl_certificate arn:aws:acm:eu-west-2:794038252750:certificate/099e7f9b-82a5-4ecd-883a-bc15beeac485

# Import existing ALB (if it exists)
echo "⚖️ Importing existing Application Load Balancer..."
terraform import module.aws-ecs.aws_lb.api_service_alb arn:aws:elasticloadbalancing:eu-west-2:794038252750:loadbalancer/app/api-load-balancer/e3be1004c7f37697

echo "✅ Import complete! Your existing infrastructure is now managed by Terraform."
echo ""
echo "🎯 Next steps:"
echo "   1. Run 'terraform plan' to see any remaining changes"
echo "   2. Use targeted applies if needed for dependency cycles"
echo "   3. Your data and resources are preserved"