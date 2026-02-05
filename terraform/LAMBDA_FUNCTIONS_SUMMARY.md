# Lambda Functions Deployment Summary

## 🚀 **Complete Lambda Infrastructure**

### **Core Data Processing Lambdas**
1. **smart-device-kinesis-to-s3** (Module)
   - **Purpose**: Processes real-time IoT data from Kinesis to S3
   - **Runtime**: Python 3.9
   - **Trigger**: Kinesis Data Stream
   - **Layers**: AWS Wrangler, FlattenJSON
   - **Source**: `lambda/smart-device-to-s3-raw/`

2. **smart-device-to-rds** (Module)
   - **Purpose**: Processes parsed device data to RDS
   - **Runtime**: Python 3.12
   - **Trigger**: Parsed Device Kinesis Stream
   - **Layers**: Pandas, SQLAlchemy
   - **Source**: `lambda/smart-device-to-rds/`

### **FTP Processing Lambdas**
3. **ftp_to_s3** (Direct Resource)
   - **Purpose**: Downloads files from FTP server to S3
   - **Runtime**: Python 3.12
   - **Trigger**: EventBridge (scheduled)
   - **Source**: `lambda/connect-to-ftp/lambda_function.zip`

4. **s3_to_rds_lambda** (Direct Resource)
   - **Purpose**: Processes FTP files from S3 to RDS
   - **Runtime**: Python 3.12
   - **Trigger**: S3 Object Created events (.csv files)
   - **Layers**: Pandas, SQLAlchemy
   - **Source**: `lambda/connect-ftp-to-rds/lambda_function.zip`

### **🆕 Enhanced Site-Aware Lambdas**
5. **enhanced-ftp-processor** (New)
   - **Purpose**: Site-aware FTP processing with tier-based logic
   - **Runtime**: Python 3.12
   - **Trigger**: EventBridge (tier-specific scheduling)
   - **Features**: 
     - Loads site configuration from S3
     - Publishes CloudWatch metrics for NON_CRITICAL sites
     - Timestamp-aware processing
   - **Source**: Generated from `aws-enhanced-lambda/enhanced_ftp_lambda.py`

### **Site Management Lambdas**
6. **site-config-manager** (New)
   - **Purpose**: Manages site configuration and tier switching
   - **Runtime**: Python 3.9
   - **Trigger**: Manual invocation / API calls
   - **Features**:
     - Get/update site configurations
     - Validate site assignments
     - Cache management
   - **Source**: Generated from `aws-site-config/site_config_manager.py`

### **Monitoring & Alerting Lambdas**
7. **SNS_Alarm_Message_Trigger** (New)
   - **Purpose**: Processes CloudWatch alarm notifications
   - **Runtime**: Python 3.12
   - **Trigger**: SNS Topic (CloudWatch Alarms)
   - **Features**: Alarm processing and routing
   - **Source**: Generated inline code

## 🔧 **Lambda Layers Used**

### **Pre-built Layers**
- **python-awswrangler**: AWS Data Wrangler for S3/Athena operations
- **python-pandas**: Data processing and analysis
- **python-flattenjson**: JSON flattening utilities
- **python-sqlalchemy**: Database ORM and connectivity

### **External Layers (Hardcoded ARNs)**
- `arn:aws:lambda:eu-west-2:794038252750:layer:python-pandas:4`
- `arn:aws:lambda:eu-west-2:794038252750:layer:sqlchemy:1`

## 🔄 **Site Switching Integration**

### **Configuration-Aware Processing**
- **Enhanced FTP Lambda** checks site tier from S3 configuration
- **CRITICAL sites**: Real-time IoT + daily FTP backup
- **NON_CRITICAL sites**: FTP-only with hourly sync + CloudWatch metrics

### **EventBridge Integration**
- **Critical Sites Rule**: Daily at 11 PM
- **Non-Critical Sites Rule**: Every hour
- Both trigger the enhanced FTP processor with tier-specific parameters

## 📊 **Environment Variables**

### **FTP Configuration**
```
FTP_HOST, FTP_USER, FTP_PASS, FTP_FOLDER
S3_BUCKET, S3_FOLDER
```

### **Database Configuration**
```
DB_HOST, DB_NAME, DB_USER, DB_PASSWORD, DB_PORT
RDS_ENDPOINT, RDS_INSTANCE_ARN, SECRET_ARN
```

### **Site Management**
```
SITE_CONFIG_BUCKET = "smarterise-site-config"
```

## 🚦 **Triggers & Event Sources**

1. **Kinesis Streams**: Real-time IoT data processing
2. **S3 Events**: FTP file processing (.csv suffix)
3. **EventBridge Rules**: Scheduled FTP operations (tier-aware)
4. **SNS Topics**: CloudWatch alarm notifications
5. **Manual Invocation**: Site configuration management

## 🔐 **IAM Roles & Permissions**

### **Main Lambda Role** (`data_lake_iam_for_lambda`)
- S3 access (all buckets)
- Kinesis read/write
- RDS Data API access
- Secrets Manager access
- CloudWatch Logs
- EC2 network interfaces

### **FTP Lambda Role** (`ftp_to_s3_lambda_role`)
- S3 access (FTP bucket)
- CloudWatch Logs

### **S3-to-RDS Role** (`lambda_s3_to_rds_role`)
- S3 read access
- RDS connectivity
- CloudWatch Logs

### **Site Config Role** (`site-config-manager-role`)
- S3 access (site config bucket)
- CloudWatch Logs

## 🎯 **Key Features Implemented**

### ✅ **Complete Data Pipeline**
- IoT → Kinesis → Lambda → S3/RDS
- FTP → S3 → Lambda → RDS

### ✅ **Site Switching System**
- Centralized configuration in S3
- Tier-aware processing logic
- Dynamic EventBridge scheduling

### ✅ **Enhanced Monitoring**
- CloudWatch metrics with actual timestamps
- SNS alarm processing
- Comprehensive logging

### ✅ **Security & Best Practices**
- No hardcoded credentials
- Proper IAM roles and policies
- Environment variable management
- Layer-based dependency management

## 🚀 **Deployment Status**

All Lambda functions are now properly configured and ready for deployment:

```bash
terraform plan   # Review the Lambda infrastructure
terraform apply  # Deploy all Lambda functions
```

The infrastructure now includes **7 Lambda functions** covering:
- Real-time IoT data processing
- FTP file processing  
- Site configuration management
- Enhanced site-aware processing
- Monitoring and alerting

This provides a complete, production-ready Lambda infrastructure with the innovative site switching capabilities! 🎉