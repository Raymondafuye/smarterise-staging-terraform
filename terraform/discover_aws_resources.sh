#!/bin/bash

# AWS Resource Discovery Script
# This script checks what actually exists in AWS before importing

echo "🔍 Discovering AWS resources in eu-west-2..."

echo ""
echo "📦 S3 Buckets:"
aws s3api list-buckets --region eu-west-2 --query 'Buckets[?contains(Name, `smarterise`) || contains(Name, `datalake`)].Name' --output table

echo ""
echo "🔐 Secrets Manager:"
aws secretsmanager list-secrets --region eu-west-2 --query 'SecretList[?contains(Name, `rds`) || contains(Name, `postgresql`)].Name' --output table

echo ""
echo "🗄️ RDS Instances:"
aws rds describe-db-instances --region eu-west-2 --query 'DBInstances[].DBInstanceIdentifier' --output table

echo ""
echo "⚡ Lambda Functions:"
aws lambda list-functions --region eu-west-2 --query 'Functions[?contains(FunctionName, `smart`) || contains(FunctionName, `ftp`) || contains(FunctionName, `s3`) || contains(FunctionName, `rds`) || contains(FunctionName, `SNS`) || contains(FunctionName, `site`)].FunctionName' --output table

echo ""
echo "🌊 Kinesis Streams:"
aws kinesis list-streams --region eu-west-2 --query 'StreamNames' --output table

echo ""
echo "⚖️ Load Balancers:"
aws elbv2 describe-load-balancers --region eu-west-2 --query 'LoadBalancers[].{Name:LoadBalancerName,ARN:LoadBalancerArn}' --output table

echo ""
echo "🐳 ECS Clusters:"
aws ecs list-clusters --region eu-west-2 --query 'clusterArns' --output table

echo ""
echo "🐳 ECS Services:"
aws ecs list-services --region eu-west-2 --cluster api_service_cluster --query 'serviceArns' --output table 2>/dev/null || echo "No ECS services found or cluster doesn't exist"

echo ""
echo "🌐 Route53 Hosted Zones:"
aws route53 list-hosted-zones --query 'HostedZones[?contains(Name, `demo`) || contains(Name, `powersmarter`) || contains(Name, `smarterise`)].{Name:Name,Id:Id}' --output table

echo ""
echo "🔒 ACM Certificates:"
aws acm list-certificates --region eu-west-2 --query 'CertificateSummaryList[?contains(DomainName, `demo`) || contains(DomainName, `powersmarter`) || contains(DomainName, `smarterise`)].{Domain:DomainName,ARN:CertificateArn}' --output table

echo ""
echo "✅ Discovery complete! Use this information to create accurate import commands."