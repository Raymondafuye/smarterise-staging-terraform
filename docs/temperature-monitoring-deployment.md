# Temperature Monitoring FTP-to-S3 Deployment Guide

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Directory Structure](#directory-structure)
- [Prerequisites](#prerequisites)
- [Deployment Instructions](#deployment-instructions)
- [Configuration Guide](#configuration-guide)
- [Testing Procedures](#testing-procedures)
- [Monitoring Setup](#monitoring-setup)
- [Schedule Management](#schedule-management)
- [Troubleshooting](#troubleshooting)
- [Cost Optimization](#cost-optimization)
- [Data Structure Examples](#data-structure-examples)
- [Security Best Practices](#security-best-practices)
- [Maintenance](#maintenance)

## Overview

This solution provides a production-ready, cost-optimized AWS infrastructure to automatically download temperature monitoring data (thermal images and CSV files) from an FTP server and store them in S3. The system is designed to cost approximately $3-4/month and includes:

- **Memory-safe file transfers** using `/tmp` and `s3.upload_file()`
- **Active Day Logic** for continuous current-day data collection
- **FTP retry logic** with exponential backoff
- **Checkpoint/resume** for incremental processing
- **Idempotency** to prevent duplicate uploads
- **Batch processing** to avoid Lambda timeouts

## Architecture

```
┌─────────────────┐
│  EventBridge    │  Hourly: cron(0 * * * ? *)
│   Schedule      │
└────────┬────────┘
         │ Triggers
         ▼
┌─────────────────┐
│  Lambda         │  Python 3.12, 512MB, 900s timeout
│  temperature-   │  NO VPC (cost optimization)
│  ftp-to-s3      │
└────────┬────────┘
         │
         ├──────────────┐
         │              │
         ▼              ▼
┌─────────────┐  ┌──────────────┐
│  FTP Server │  │  S3 Bucket   │
│             │  │  smarterise- │
│  /C368/     │  │  thermal-    │
│  /C468/     │  │  data        │
└─────────────┘  └──────────────┘
                        │
                        ▼
                 ┌──────────────┐
                 │  Checkpoint  │
                 │  state/      │
                 │  ingest_     │
                 │  checkpoint  │
                 │  .json       │
                 └──────────────┘
```

### AWS Resources Created

1. **S3 Bucket** (`smarterise-thermal-data`)
   - Server-side encryption (AES256)
   - Versioning enabled
   - Private ACL

2. **Lambda Function** (`temperature-ftp-to-s3`)
   - Runtime: Python 3.12
   - Memory: 512 MB
   - Timeout: 900 seconds (15 minutes)
   - **No VPC** (critical for cost optimization)

3. **IAM Role & Policy**
   - S3 permissions: GetObject, PutObject, DeleteObject, ListBucket, HeadObject
   - CloudWatch Logs permissions

4. **CloudWatch Log Group** (`/aws/lambda/temperature-ftp-to-s3`)
   - Retention: 3 days

5. **EventBridge Schedule**
   - Default: Hourly (`cron(0 * * * ? *)`)
   - Configurable via Terraform variables

## Features

### 1. Memory-Safe File Transfers
- Downloads files to `/tmp` using `ftp.retrbinary()`
- Uploads to S3 using `s3.upload_file()`
- Prevents out-of-memory errors with large files
- Automatic cleanup of temporary files

### 2. Active Day Logic
- Processes today's folder in every run
- Only updates checkpoint for past dates
- Ensures current-day files are continuously collected
- Example:
  - Today: 2026-02-05
  - Processes: 2026-02-03, 2026-02-04, 2026-02-05
  - Checkpoints: 2026-02-03, 2026-02-04 (NOT today)
  - Next run: Will process 2026-02-05 again (picks up new files)

### 3. FTP Connection Retry Logic
- 3 retry attempts with exponential backoff
- Delays: 1 second, 2 seconds, 4 seconds
- Handles transient network failures
- Logs all retry attempts

### 4. Checkpoint/Resume Mechanism
- Tracks progress per site in S3
- Stored at: `s3://bucket/state/ingest_checkpoint.json`
- Format: `{"C368": "2026-02-04", "C468": "2026-02-03"}`
- Enables incremental processing
- Survives Lambda restarts

### 5. Idempotency
- Checks if file exists in S3 before downloading
- Uses `s3.head_object()` for efficient checking
- Safe to re-run without duplicating data
- Deletes files from FTP even if already in S3

### 6. Batch Processing
- Processes 2 past dates + today per run
- Prevents Lambda timeouts (900-second limit)
- For large historical backlogs, catches up over multiple runs
- Hourly schedule ensures continuous progress

### 7. FTP Cleanup
- Deletes files after successful S3 upload
- Removes empty `thermal/` folders
- Removes empty date folders
- Keeps FTP server clean

## Directory Structure

```
smarterise-staging-terraform/
├── lambda/
│   └── temperature-ftp-to-s3/
│       ├── lambda_function.py       # Main Lambda code
│       ├── lambda_function.zip      # Deployment package
│       └── README.md                # Lambda documentation
├── terraform/
│   ├── aws-s3/
│   │   ├── main.tf                  # S3 bucket resources
│   │   ├── variables.tf             # S3 variables
│   │   └── outputs.tf               # S3 outputs
│   ├── aws-lambda/
│   │   ├── main.tf                  # Lambda resources
│   │   └── variables.tf             # Lambda variables
│   ├── main.tf                      # Root module
│   ├── variables.tf                 # Root variables
│   ├── outputs.tf                   # Root outputs
│   └── terraform.tfvars.temperature.example  # Example config
└── docs/
    └── temperature-monitoring-deployment.md  # This file
```

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** installed (v1.0+)
3. **AWS CLI** configured with credentials
4. **PowerShell** (for Windows deployment)
5. **FTP Server** credentials and access
6. **Git** for version control

## Deployment Instructions

### Step 1: Clone and Navigate

```powershell
cd c:\Users\chiom\Projects\smarterise-staging-terraform
git checkout feature/ftp-to-s3-temperature-monitoring
```

### Step 2: Create Lambda Deployment Package

```powershell
cd lambda\temperature-ftp-to-s3
Compress-Archive -Path lambda_function.py -DestinationPath lambda_function.zip -Force
cd ..\..
```

Verify the zip file was created:
```powershell
Test-Path lambda\temperature-ftp-to-s3\lambda_function.zip
# Should return: True
```

### Step 3: Configure Terraform Variables

Create `terraform/terraform.tfvars` with your actual values:

```powershell
cd terraform
Copy-Item terraform.tfvars.temperature.example terraform.tfvars
notepad terraform.tfvars
```

Update the following values:

```hcl
# S3 Bucket (must be globally unique)
temperature_monitoring_bucket_name = "smarterise-thermal-data-prod"

# FTP Server Configuration
temperature_ftp_host   = "ftp.yourserver.com"
temperature_ftp_user   = "your-username"
temperature_ftp_pass   = "your-secure-password"
temperature_ftp_folder = "/"

# Site Configuration
temperature_site_ids = "C368,C468"

# Schedule (Hourly by default)
temperature_schedule_expression = "cron(0 * * * ? *)"
temperature_schedule_enabled    = true
```

### Step 4: Initialize Terraform

```powershell
terraform init
```

Expected output:
```
Initializing modules...
Initializing the backend...
Initializing provider plugins...
Terraform has been successfully initialized!
```

### Step 5: Validate Configuration

```powershell
terraform validate
```

Expected output:
```
Success! The configuration is valid.
```

### Step 6: Review Terraform Plan

```powershell
terraform plan
```

Review the plan carefully. You should see:
- 1 S3 bucket to be created
- 1 Lambda function to be created
- 1 IAM role to be created
- 1 IAM policy to be created
- 1 CloudWatch log group to be created
- 1 EventBridge rule to be created
- Related permissions and attachments

### Step 7: Apply Terraform Configuration

```powershell
terraform apply
```

Type `yes` when prompted. Deployment takes approximately 2-3 minutes.

### Step 8: Verify Deployment

Check the outputs:

```powershell
terraform output
```

You should see:
```
temperature_monitoring_bucket_name = "smarterise-thermal-data-prod"
temperature_monitoring_bucket_arn = "arn:aws:s3:::smarterise-thermal-data-prod"
```

## Configuration Guide

### Environment Variables

The Lambda function uses the following environment variables (configured via Terraform):

| Variable | Description | Example |
|----------|-------------|---------|
| `FTP_HOST` | FTP server hostname | `ftp.smarterise.com` |
| `FTP_USER` | FTP username | `monitoring_user` |
| `FTP_PASS` | FTP password | `secure_password` |
| `FTP_FOLDER` | Root folder on FTP | `/thermal-data` or `/` |
| `S3_BUCKET` | S3 bucket name | `smarterise-thermal-data` |
| `SITE_IDS` | Comma-separated site IDs | `C368,C468` |

### Schedule Configuration

The EventBridge schedule can be configured using cron expressions or rate expressions:

**Hourly** (default):
```hcl
temperature_schedule_expression = "cron(0 * * * ? *)"
```

**Every 15 minutes**:
```hcl
temperature_schedule_expression = "rate(15 minutes)"
```

**Every 6 hours**:
```hcl
temperature_schedule_expression = "cron(0 */6 * * ? *)"
```

**Daily at 2 AM UTC**:
```hcl
temperature_schedule_expression = "cron(0 2 * * ? *)"
```

After changing the schedule, run:
```powershell
terraform apply
```

### Adding/Removing Sites

To add or remove sites, update `terraform.tfvars`:

```hcl
temperature_site_ids = "C368,C468,C500,C600"
```

Then apply:
```powershell
terraform apply
```

## Testing Procedures

### Manual Lambda Invocation

1. Go to AWS Console → Lambda → `temperature-ftp-to-s3`
2. Click "Test" tab
3. Create a new test event:
   - Event name: `TestEvent`
   - Event JSON: `{}`
4. Click "Test" button

### Verify Execution

1. **Check CloudWatch Logs**:
   - Go to CloudWatch → Log groups → `/aws/lambda/temperature-ftp-to-s3`
   - View the latest log stream
   - Look for:
     - "Successfully connected to FTP server"
     - "Processing site: C368"
     - "Uploaded to S3 successfully"
     - "Temperature monitoring ingestion completed successfully"

2. **Check S3 Bucket**:
   ```powershell
   aws s3 ls s3://smarterise-thermal-data-prod/ --recursive
   ```
   
   Expected structure:
   ```
   C368/2026-02-05/thermal/image_001.png
   C368/2026-02-05/thermal/image_002.png
   C368/2026-02-05/data.csv
   C468/2026-02-05/thermal/image_001.png
   state/ingest_checkpoint.json
   ```

3. **Check Checkpoint**:
   ```powershell
   aws s3 cp s3://smarterise-thermal-data-prod/state/ingest_checkpoint.json -
   ```
   
   Expected output:
   ```json
   {
     "C368": "2026-02-04",
     "C468": "2026-02-04"
   }
   ```

4. **Check FTP Server**:
   - Verify files were deleted from FTP
   - Verify empty folders were removed

## Monitoring Setup

### CloudWatch Metrics

Monitor these Lambda metrics in CloudWatch:

1. **Invocations**
   - Expected: ~24/day (hourly schedule)
   - Alert if: < 20/day

2. **Duration**
   - Expected: 1-5 minutes
   - Alert if: > 10 minutes

3. **Errors**
   - Expected: 0
   - Alert if: > 0

4. **Throttles**
   - Expected: 0
   - Alert if: > 0

### Creating CloudWatch Alarms

**Lambda Error Alarm**:

```powershell
aws cloudwatch put-metric-alarm `
  --alarm-name temperature-ftp-lambda-errors `
  --alarm-description "Alert on Lambda errors" `
  --metric-name Errors `
  --namespace AWS/Lambda `
  --statistic Sum `
  --period 300 `
  --evaluation-periods 1 `
  --threshold 1 `
  --comparison-operator GreaterThanThreshold `
  --dimensions Name=FunctionName,Value=temperature-ftp-to-s3
```

**Lambda Duration Alarm**:

```powershell
aws cloudwatch put-metric-alarm `
  --alarm-name temperature-ftp-lambda-duration `
  --alarm-description "Alert on long Lambda execution" `
  --metric-name Duration `
  --namespace AWS/Lambda `
  --statistic Average `
  --period 300 `
  --evaluation-periods 1 `
  --threshold 600000 `
  --comparison-operator GreaterThanThreshold `
  --dimensions Name=FunctionName,Value=temperature-ftp-to-s3
```

### CloudWatch Logs Insights Queries

**Files Processed Per Run**:
```
fields @timestamp, @message
| filter @message like /Uploaded to S3 successfully/
| stats count() by bin(5m)
```

**FTP Connection Failures**:
```
fields @timestamp, @message
| filter @message like /FTP connection attempt/
| filter @message like /failed/
```

**Checkpoint Updates**:
```
fields @timestamp, @message
| filter @message like /Updated checkpoint/
```

## Schedule Management

### Disable Schedule

To temporarily disable the schedule without destroying resources:

```hcl
# In terraform.tfvars
temperature_schedule_enabled = false
```

Apply:
```powershell
terraform apply
```

### Re-enable Schedule

```hcl
# In terraform.tfvars
temperature_schedule_enabled = true
```

Apply:
```powershell
terraform apply
```

### Change Schedule Frequency

Update `terraform.tfvars` and apply:

```hcl
# Every 30 minutes
temperature_schedule_expression = "rate(30 minutes)"
```

```powershell
terraform apply
```

## Troubleshooting

### Issue: FTP Connection Fails

**Symptoms**: "All FTP connection attempts failed" in CloudWatch Logs

**Solutions**:
1. Verify FTP credentials in `terraform.tfvars`
2. Check FTP server is accessible from internet (Lambda has no VPC)
3. Verify FTP_HOST is correct
4. Check FTP server allows connections from AWS IP ranges
5. Test FTP connection manually:
   ```powershell
   ftp ftp.yourserver.com
   ```

### Issue: Files Not Uploading to S3

**Symptoms**: Files remain on FTP, not in S3

**Solutions**:
1. Check IAM role has `s3:PutObject` permission
2. Verify S3 bucket name is correct
3. Check CloudWatch Logs for specific errors
4. Verify Lambda has sufficient memory (512 MB)
5. Check file sizes (Lambda `/tmp` has 512 MB limit)

### Issue: Lambda Timeout

**Symptoms**: Lambda execution exceeds 900 seconds

**Solutions**:
1. Reduce batch size (currently 2 dates per run)
2. Check for very large files causing slow transfers
3. Verify FTP connection is stable
4. Consider increasing Lambda timeout (max 15 minutes)
5. Check network latency to FTP server

### Issue: Checkpoint Not Updating

**Symptoms**: Same dates processed repeatedly

**Solutions**:
1. Check IAM role has `s3:PutObject` permission for checkpoint
2. Verify checkpoint logic in CloudWatch Logs
3. Check for errors during checkpoint save
4. Verify Active Day Logic is working (today should NOT update checkpoint)
5. Manually inspect checkpoint file:
   ```powershell
   aws s3 cp s3://bucket/state/ingest_checkpoint.json -
   ```

### Issue: Duplicate Files in S3

**Symptoms**: Same file uploaded multiple times

**Solutions**:
1. Verify idempotency check is working (`s3.head_object()`)
2. Check IAM role has `s3:HeadObject` permission
3. Review CloudWatch Logs for "SKIP (exists in S3)" messages
4. Check S3 versioning (may show multiple versions)
5. Verify file names are consistent between runs

### Issue: High Costs

**Symptoms**: Monthly costs exceed $3-4

**Solutions**:
1. Verify Lambda is NOT in a VPC (saves $33/month NAT Gateway cost)
2. Check Lambda invocation count (should be ~720/month for hourly)
3. Review Lambda duration (should be 1-5 minutes)
4. Check S3 storage costs (depends on data volume)
5. Verify CloudWatch Logs retention is 3 days

## Cost Optimization

### Monthly Cost Breakdown

| Service | Usage | Cost |
|---------|-------|------|
| Lambda Invocations | 720/month (hourly) | $0.0001 |
| Lambda Duration | 2 min/run × 720 runs × 0.5 GB | $0.72 |
| S3 Storage | Variable (depends on data) | $0.50-2.00 |
| S3 Requests | ~5,000/month | $0.03 |
| CloudWatch Logs | 3-day retention | $0.50 |
| EventBridge | 720 invocations/month | $0.00 |
| **Total** | | **$3-4/month** |

### Cost Optimization Strategies

1. **No VPC**: Lambda accesses FTP directly over internet
   - Saves: $33/month (NAT Gateway cost)
   - Trade-off: FTP must be internet-accessible

2. **Short Log Retention**: CloudWatch Logs kept for 3 days only
   - Saves: ~$5/month vs. 30-day retention
   - Trade-off: Limited historical logs

3. **Efficient Batch Processing**: Processes 2 dates per run
   - Minimizes Lambda invocations
   - Prevents timeouts

4. **Hourly Schedule**: Balances recency with cost
   - 720 invocations/month vs. 2,880 for 15-minute schedule
   - Saves: ~$2/month

## Data Structure Examples

### FTP Structure

```
/
  C368/
    2026-02-03/
      thermal/
        image_001.png
        image_002.png
        image_003.png
      data.csv
      summary.csv
    2026-02-04/
      thermal/
        image_001.png
      data.csv
    2026-02-05/
      thermal/
        image_001.png
        image_002.png
      data.csv
  C468/
    2026-02-03/
      thermal/
        image_001.png
      data.csv
    2026-02-04/
      thermal/
        image_001.png
        image_002.png
      data.csv
```

### S3 Structure

```
s3://smarterise-thermal-data/
  C368/
    2026-02-03/
      thermal/
        image_001.png
        image_002.png
        image_003.png
      data.csv
      summary.csv
    2026-02-04/
      thermal/
        image_001.png
      data.csv
  C468/
    2026-02-03/
      thermal/
        image_001.png
      data.csv
    2026-02-04/
      thermal/
        image_001.png
        image_002.png
      data.csv
  state/
    ingest_checkpoint.json
```

### Checkpoint Format

```json
{
  "C368": "2026-02-04",
  "C468": "2026-02-04"
}
```

This means:
- C368: Last completed date is 2026-02-04
- C468: Last completed date is 2026-02-04
- Next run will process: 2026-02-05 (and today if it exists)

## Security Best Practices

### 1. Credentials Management

✅ **DO**:
- Store FTP credentials in `terraform.tfvars` (gitignored)
- Use AWS Secrets Manager for production (optional enhancement)
- Rotate FTP passwords regularly
- Use strong, unique passwords

❌ **DON'T**:
- Hardcode credentials in Lambda code
- Commit `terraform.tfvars` to Git
- Share credentials via email or chat

### 2. IAM Permissions

✅ **DO**:
- Follow least privilege principle
- Grant only necessary S3 permissions
- Use separate IAM roles for different functions
- Review IAM policies regularly

❌ **DON'T**:
- Use `s3:*` permissions (too broad)
- Share IAM credentials
- Use root account for deployment

### 3. S3 Security

✅ **DO**:
- Enable server-side encryption (AES256)
- Enable versioning for data protection
- Use private ACL (no public access)
- Enable S3 bucket logging (optional)

❌ **DON'T**:
- Make bucket public
- Disable encryption
- Allow anonymous access

### 4. Network Security

✅ **DO**:
- Use FTPS/SFTP if available (more secure than FTP)
- Whitelist AWS IP ranges on FTP server (optional)
- Monitor FTP access logs

❌ **DON'T**:
- Use FTP over public internet without encryption (if avoidable)
- Expose FTP credentials in logs

## Maintenance

### Regular Tasks

**Weekly**:
- Review CloudWatch Logs for errors
- Check Lambda invocation count
- Verify checkpoint is updating

**Monthly**:
- Review AWS costs
- Check S3 storage usage
- Rotate FTP credentials (if policy requires)
- Review IAM permissions

**Quarterly**:
- Update Lambda runtime if new version available
- Review and optimize batch size
- Test disaster recovery procedures

### Updating FTP Credentials

1. Update `terraform.tfvars`:
   ```hcl
   temperature_ftp_pass = "new-secure-password"
   ```

2. Apply changes:
   ```powershell
   terraform apply
   ```

3. Verify:
   - Manually invoke Lambda
   - Check CloudWatch Logs for successful FTP connection

### Updating Lambda Code

1. Modify `lambda/temperature-ftp-to-s3/lambda_function.py`

2. Recreate deployment package:
   ```powershell
   cd lambda\temperature-ftp-to-s3
   Compress-Archive -Path lambda_function.py -DestinationPath lambda_function.zip -Force
   cd ..\..
   ```

3. Apply changes:
   ```powershell
   cd terraform
   terraform apply
   ```

### Disaster Recovery

**Backup Checkpoint**:
```powershell
aws s3 cp s3://smarterise-thermal-data/state/ingest_checkpoint.json ./checkpoint-backup.json
```

**Restore Checkpoint**:
```powershell
aws s3 cp ./checkpoint-backup.json s3://smarterise-thermal-data/state/ingest_checkpoint.json
```

**Reset Checkpoint** (re-process all data):
```powershell
aws s3 rm s3://smarterise-thermal-data/state/ingest_checkpoint.json
```

### Decommissioning

To remove all resources:

```powershell
cd terraform
terraform destroy
```

**Warning**: This will delete:
- Lambda function
- EventBridge schedule
- IAM role and policy
- CloudWatch log group
- S3 bucket (if `force_destroy = true`)

---

## Support

For issues or questions:
1. Check CloudWatch Logs first
2. Review this documentation
3. Check Terraform state: `terraform show`
4. Contact DevOps team

## Version History

- **v1.0** (2026-02-05): Initial release
  - Memory-safe file transfers
  - Active Day Logic
  - FTP retry logic
  - Checkpoint/resume
  - Idempotency
  - Batch processing
