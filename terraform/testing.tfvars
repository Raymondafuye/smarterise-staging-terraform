# Enable expensive resources for testing
enable_expensive_resources = true

### Temperature Monitoring Configuration ###
# Credentials are in terraform.tfvars (which is gitignored)
temperature_monitoring_bucket_name = "smarterise-thermal-data"
temperature_ftp_host               = "ftp.smarterise.com"
temperature_ftp_folder             = "/"
temperature_site_ids               = "C368,C468"

# Schedule (Default to hourly)
temperature_schedule_expression    = "cron(0 * * * ? *)"
temperature_schedule_enabled       = true