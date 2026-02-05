# Site Switching & Automated Reporting System

## Overview
This system provides centralized site switching between CRITICAL and NON_CRITICAL tiers with unified automated reporting for both real-time and FTP-only sites.

## Architecture Components

### 1. Site Configuration Management
- **S3 Bucket**: `smarterise-site-config`
- **Configuration File**: `site-tiers.json`
- **Lambda Function**: `site-config-manager`

### 2. Site Tiers

#### CRITICAL Tier
- Real-time IoT data processing
- Daily FTP backup at 11 PM
- Immediate CloudWatch alarms
- Real-time metrics publishing

#### NON_CRITICAL Tier  
- FTP-only monitoring
- Hourly FTP sync
- Daily summary alarms
- Hourly CloudWatch metrics via FTP processing

### 3. Enhanced Infrastructure
- **Enhanced EventBridge**: Flexible scheduling per tier
- **Site-Aware Lambda**: Configuration-driven processing
- **Conditional IoT Rules**: Only deployed for CRITICAL sites

## Site Switching Process

### 1. View Current Configuration
```bash
aws s3 cp s3://smarterise-site-config/site-tiers.json .
cat site-tiers.json
```

### 2. Switch Site Tier
Edit the JSON file:
```json
{
  "version": "1.0",
  "last_updated": "2024-01-15T10:30:00Z",
  "sites": {
    "AN54101354": {
      "asset_id": "C354",
      "tier": "NON_CRITICAL",  // Changed from CRITICAL
      "enabled": true
    }
  }
}
```

### 3. Apply Changes
```bash
aws s3 cp site-tiers.json s3://smarterise-site-config/
```

### 4. Verify Changes (within 5 minutes)
```bash
aws lambda invoke --function-name site-config-manager \
  --payload '{"action": "get_site", "gateway_serial": "AN54101354"}' \
  response.json
```

## What Happens When Switching

### NON_CRITICAL → CRITICAL
- Site starts receiving real-time IoT data
- FTP sync changes from hourly to daily backup
- Alarms switch from daily summary to immediate
- CloudWatch metrics published in real-time

### CRITICAL → NON_CRITICAL
- Real-time IoT processing stops
- FTP sync changes from daily to hourly
- Alarms switch from immediate to daily summary
- CloudWatch metrics published hourly via FTP

## Benefits

### Operational
- **Single Point of Control**: One file controls all site behavior
- **No Manual File Editing**: Simple JSON configuration changes
- **Immediate Effect**: Changes apply within 5 minutes
- **Audit Trail**: All configuration changes logged

### Technical
- **Unified Reporting**: Both tiers use same alarm/email system
- **Accurate Timestamps**: Daily summaries work correctly for both tiers
- **Cost Optimization**: NON_CRITICAL sites use cheaper FTP-only monitoring
- **Backward Compatible**: Existing sites continue working during migration

### Reporting
- **FTP Sites Get Automated Reports**: No more manual reporting gaps
- **Same Email Templates**: Consistent reporting format
- **Correct Daily Summaries**: Measurement timestamps ensure accurate reporting
- **Flexible Timing**: Immediate vs daily summary alerts per tier

## Configuration File Structure

```json
{
  "version": "1.0",
  "last_updated": "2024-01-15T10:30:00Z",
  "sites": {
    "gateway_serial": {
      "asset_id": "C025",
      "tier": "CRITICAL|NON_CRITICAL",
      "enabled": true|false
    }
  }
}
```

## Lambda Functions

### site-config-manager
Manages configuration updates and provides API for configuration changes.

**API Actions**:
- `get_config`: Return full configuration
- `get_site`: Return specific site information  
- `update_sites`: Update site configurations

### Enhanced FTP Lambda
Processes FTP data with site-aware logic:
- Always inserts data into RDS
- For NON_CRITICAL sites: publishes CloudWatch metrics with actual timestamps
- Handles both S3 triggers and EventBridge scheduled events

## EventBridge Scheduling

### CRITICAL Sites
- **Schedule**: Daily at 11 PM
- **Purpose**: FTP backup for redundancy

### NON_CRITICAL Sites  
- **Schedule**: Every hour
- **Purpose**: Primary data collection and processing

## Monitoring & Alerts

All sites use the same CloudWatch alarms and SNS notifications, ensuring consistent reporting regardless of tier. The key difference is timing:

- **CRITICAL**: Real-time alerts
- **NON_CRITICAL**: Daily summary alerts with correct measurement timestamps

## Deployment

The system is deployed as part of the main Terraform configuration:

```hcl
module "aws-site-config" {
  source = "./aws-site-config"
  site_config_bucket_name = var.site_config_bucket_name
  smart_device_names = var.smart_device_names
}

module "aws-enhanced-eventbridge" {
  source = "./aws-enhanced-eventbridge"
  ftp_lambda_arn = module.aws-lambda.ftp_lambda_arn
  ftp_lambda_function_name = module.aws-lambda.ftp_lambda_function_name
}
```

## Troubleshooting

### Configuration Not Loading
- Check S3 bucket permissions
- Verify `site-tiers.json` exists and is valid JSON
- Check Lambda logs for `site-config-manager`

### Site Not Switching Behavior
- Wait 5 minutes for Lambda cache refresh
- Verify configuration was uploaded correctly
- Check EventBridge rules are enabled

### Missing Metrics for NON_CRITICAL Sites
- Verify FTP data is being processed
- Check enhanced FTP Lambda logs
- Ensure CloudWatch permissions are correct