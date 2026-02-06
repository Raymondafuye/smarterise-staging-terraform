# Temperature Monitoring FTP-to-S3 Lambda

Production-ready Lambda function that downloads thermal images and CSV files from an FTP server and uploads them to S3.

## Features

- **Memory-Safe Transfers**: Downloads to `/tmp` using `ftp.retrbinary()`, uploads with `s3.upload_file()` to avoid memory issues
- **Active Day Logic**: Continuously processes today's folder without updating checkpoint, ensuring current-day files are always picked up
- **FTP Retry Logic**: 3 connection attempts with exponential backoff (1s, 2s, 4s delays)
- **Checkpoint/Resume**: Tracks progress per site in `s3://bucket/state/ingest_checkpoint.json`
- **Idempotency**: Uses `s3.head_object()` to skip files already in S3
- **Batch Processing**: Processes 2 past dates + today per run to avoid timeouts
- **FTP Cleanup**: Deletes files after successful upload, removes empty folders
- **Comprehensive Logging**: Detailed progress tracking with `print()` statements

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `FTP_HOST` | FTP server hostname | `ftp.smarterise.com` |
| `FTP_USER` | FTP username | `monitoring_user` |
| `FTP_PASS` | FTP password | `secure_password` |
| `FTP_FOLDER` | Root folder on FTP server | `/thermal-data` or `/` |
| `S3_BUCKET` | S3 bucket name for data storage | `smarterise-thermal-data` |
| `SITE_IDS` | Comma-separated list of site IDs | `C368,C468` |

## Data Flow

### FTP Structure
```
/
  C368/
    2026-01-20/
      thermal/
        image_001.png
        image_002.png
      data.csv
    2026-01-21/
      thermal/
        image_003.png
      data.csv
  C468/
    2026-01-20/
      thermal/
        image_001.png
      data.csv
```

### S3 Structure
```
s3://smarterise-thermal-data/
  C368/
    2026-01-20/
      thermal/
        image_001.png
        image_002.png
      data.csv
    2026-01-21/
      thermal/
        image_003.png
      data.csv
  C468/
    2026-01-20/
      thermal/
        image_001.png
      data.csv
  state/
    ingest_checkpoint.json
```

### Checkpoint Format
```json
{
  "C368": "2026-01-21",
  "C468": "2026-01-20"
}
```

## Processing Logic

### Active Day Logic

The function implements "Active Day Logic" to ensure current-day data is continuously collected:

1. **Get today's date** (UTC): `2026-01-22`
2. **Load checkpoint**: `{"C368": "2026-01-20"}`
3. **Find dates to process**: All dates after `2026-01-20`
4. **Separate past vs. today**:
   - Past dates: `2026-01-21`
   - Today: `2026-01-22` (if exists)
5. **Process batch**: 2 past dates + today = `[2026-01-21, 2026-01-22]`
6. **Update checkpoint**: Only for `2026-01-21` (NOT today)
7. **Next run**: Will process `2026-01-22` again (picks up new files)

This ensures today's folder is processed in every run without premature checkpoint updates.

### Batch Processing

- Processes **2 past dates + today** per run
- Prevents Lambda timeouts (900-second limit)
- For large historical backlogs, multiple invocations catch up over time
- Hourly schedule ensures continuous progress

### Idempotency

Before downloading each file:
1. Check if file exists in S3 using `s3.head_object()`
2. If exists: Delete from FTP, skip download
3. If not exists: Download → Upload → Delete from FTP

Safe to re-run without duplicating data.

## Error Handling

### FTP Connection Failures
- 3 retry attempts with exponential backoff
- Delays: 1s, 2s, 4s
- Raises exception if all retries fail

### Missing Folders
- Gracefully handles missing site folders
- Skips sites without date folders
- Continues processing other sites

### File Transfer Errors
- Logs errors but continues processing other files
- Cleans up local `/tmp` files in `finally` block
- Preserves checkpoint for successful transfers

## Performance Metrics

### Expected Execution Time
- **Small batch** (10 files): ~30 seconds
- **Medium batch** (100 files): ~3-5 minutes
- **Large batch** (500 files): ~10-15 minutes
- **Timeout limit**: 15 minutes (900 seconds)

### Memory Usage
- **Lambda memory**: 512 MB
- **File size limit**: ~400 MB per file (safe margin)
- Uses `/tmp` (512 MB limit) for temporary storage

### Cost Estimate
- **Lambda invocations**: 720/month (hourly) × $0.20/1M = $0.0001
- **Lambda duration**: ~2 min/run × 720 runs × $0.0000166667/GB-sec × 0.5 GB = $0.72
- **S3 storage**: Variable (depends on data volume)
- **S3 requests**: ~$0.01/month
- **Total**: ~$3-4/month

## Deployment

### 1. Create Deployment Package

```powershell
cd c:\Users\chiom\Projects\smarterise-staging-terraform\lambda\temperature-ftp-to-s3
Compress-Archive -Path lambda_function.py -DestinationPath lambda_function.zip -Force
```

### 2. Deploy with Terraform

```powershell
cd c:\Users\chiom\Projects\smarterise-staging-terraform\terraform
terraform init
terraform plan
terraform apply
```

### 3. Configure Variables

Create `terraform/terraform.tfvars` with your FTP credentials:

```hcl
temperature_monitoring_bucket_name = "smarterise-thermal-data"
temperature_ftp_host               = "ftp.smarterise.com"
temperature_ftp_user               = "your-username"
temperature_ftp_pass               = "your-password"
temperature_ftp_folder             = "/"
temperature_site_ids               = "C368,C468"
temperature_schedule_expression    = "cron(0 * * * ? *)"  # Hourly
temperature_schedule_enabled       = true
```

## Testing

### Manual Invocation

1. Go to AWS Console → Lambda → `temperature-ftp-to-s3`
2. Click "Test" tab
3. Create test event (empty JSON: `{}`)
4. Click "Test" button
5. Check CloudWatch Logs for execution details

### Verify Results

1. **Check S3**: Verify files uploaded to `s3://bucket/{SITE_ID}/{DATE}/`
2. **Check Checkpoint**: Download `s3://bucket/state/ingest_checkpoint.json`
3. **Check FTP**: Verify files deleted from FTP server
4. **Check Logs**: Review CloudWatch Logs for errors

## Monitoring

### CloudWatch Logs

- **Log Group**: `/aws/lambda/temperature-ftp-to-s3`
- **Retention**: 3 days
- **Key Metrics**:
  - Files processed per run
  - Checkpoint updates
  - FTP connection status
  - Errors and retries

### CloudWatch Metrics

Monitor these Lambda metrics:
- **Invocations**: Should be ~24/day (hourly)
- **Duration**: Typically 1-5 minutes
- **Errors**: Should be 0
- **Throttles**: Should be 0

### Alarms (Optional)

Create CloudWatch alarms for:
- Lambda errors > 0
- Lambda duration > 10 minutes
- Lambda throttles > 0

## Troubleshooting

### Issue: FTP Connection Fails

**Symptoms**: "All FTP connection attempts failed"

**Solutions**:
- Verify FTP credentials in environment variables
- Check FTP server is accessible from internet (Lambda has no VPC)
- Verify FTP_HOST is correct
- Check FTP server allows connections from AWS IP ranges

### Issue: Files Not Uploading to S3

**Symptoms**: Files remain on FTP, not in S3

**Solutions**:
- Check IAM role has `s3:PutObject` permission
- Verify S3 bucket name is correct
- Check CloudWatch Logs for specific errors
- Verify Lambda has sufficient memory (512 MB)

### Issue: Lambda Timeout

**Symptoms**: Lambda execution exceeds 900 seconds

**Solutions**:
- Reduce batch size (currently 2 dates per run)
- Increase Lambda timeout (max 15 minutes)
- Check for very large files causing slow transfers
- Verify FTP connection is stable

### Issue: Checkpoint Not Updating

**Symptoms**: Same dates processed repeatedly

**Solutions**:
- Check IAM role has `s3:PutObject` permission for checkpoint
- Verify checkpoint logic in CloudWatch Logs
- Check for errors during checkpoint save
- Verify Active Day Logic is working (today should NOT update checkpoint)

### Issue: Duplicate Files in S3

**Symptoms**: Same file uploaded multiple times

**Solutions**:
- Verify idempotency check is working (`s3.head_object()`)
- Check IAM role has `s3:HeadObject` permission
- Review CloudWatch Logs for "SKIP (exists in S3)" messages
- Check S3 versioning (may show multiple versions)

## Maintenance

### Updating FTP Credentials

1. Update `terraform/terraform.tfvars`
2. Run `terraform apply`
3. Lambda environment variables will be updated automatically

### Changing Schedule

Update `temperature_schedule_expression` in `terraform.tfvars`:

- **Every 15 minutes**: `rate(15 minutes)`
- **Hourly**: `cron(0 * * * ? *)`
- **Every 6 hours**: `cron(0 */6 * * ? *)`
- **Daily at 2 AM UTC**: `cron(0 2 * * ? *)`

### Adding/Removing Sites

Update `temperature_site_ids` in `terraform.tfvars`:

```hcl
temperature_site_ids = "C368,C468,C500"  # Add C500
```

Run `terraform apply` to update Lambda environment variables.

### Disabling Schedule

Set `temperature_schedule_enabled = false` in `terraform.tfvars` and run `terraform apply`.

## Security Best Practices

- ✅ FTP credentials stored as Terraform variables (not hardcoded)
- ✅ `terraform.tfvars` is gitignored (never committed)
- ✅ IAM role follows least privilege principle
- ✅ S3 bucket has encryption enabled (AES256)
- ✅ S3 bucket has versioning enabled
- ✅ CloudWatch Logs have short retention (3 days)
- ✅ No VPC (reduces attack surface, saves costs)

## Dependencies

**Python Standard Library** (no external packages required):
- `os` - Environment variables, file operations
- `json` - Checkpoint serialization
- `time` - Retry delays
- `tempfile` - Temporary file storage
- `ftplib` - FTP client
- `datetime` - Date handling
- `boto3` - AWS SDK (provided by Lambda runtime)
