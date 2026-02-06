variable "datalake_raw_athena_results_storage_bucket_name" {
  description = "name of the bucket for the for results of queries in datalake raw"
  type        = string
  default     = "datalake-raw-athena-results1"
}

variable "iot_device_certificate_bucket_name" {
  description = "Bucket name to hold device certificates"
  type        = string
  default     = "smarterise-accuenergy-mqtt-certificates1"
}

variable "smarterise_domain_root" {
  description = "The root DNS name to use"
  type        = string
  default     = "dev.demo.powersmarter.net"
}
variable "rds_postgresql_username" {
  description = "Master username for the RDS PostgreSQL instance"
  type        = string
  default     = "dbadmin"
}


variable "environment" {
  description = "Environment, such as DEV, PROD etc."
  type        = string
  default     = "dev"
}

variable "datalake_raw_database_name" {
  description = "name of the athena database for datalake raw"
  type        = string
  default     = "datalake_raw1"
}

variable "smart_device_names" {
  description = "IoT device names"
  type        = list(string)
  default = [
    "ehm21120333",
    "AN54101471",
    "AN55103124"
  ]
}

variable "rds_state_bucket_name" {
  description = "Bucket name to hold RDS State"
  type        = string
  default     = "smarterise-rds-state1"
}

variable "site_config_bucket_name" {
  description = "Bucket name for site configuration management"
  type        = string
  default     = "smarterise-site-config"
}

# FTP Configuration Variables
variable "ftp_host" {
  description = "FTP server hostname"
  type        = string
  default     = "ftp.smarterise.com"
}

variable "ftp_user" {
  description = "FTP username"
  type        = string
  default     = "r.afuye@smarterise.com"
}

variable "ftp_pass" {
  description = "FTP password"
  type        = string
  sensitive   = true
  default     = null
}

variable "ftp_folder" {
  description = "FTP folder path"
  type        = string
  default     = "/307a57025366"
}

variable "s3_bucket" {
  description = "S3 bucket for FTP files"
  type        = string
  default     = "ftpfiletest"
}

variable "s3_folder" {
  description = "S3 folder prefix"
  type        = string
  default     = "ftp-backups/"
}

variable "database_url" {
  description = "Database connection URL"
  type        = string
  sensitive   = true
  default     = null
}


# Certificate management options
variable "existing_certificate_arn" {
  description = "Existing ACM certificate ARN (if available)"
  type        = string
  default     = null
}

variable "existing_certificate_arn_us_east_1" {
  description = "Existing ACM certificate ARN in us-east-1 for CloudFront"
  type        = string
  default     = null
}

variable "skip_ssl_certificate" {
  description = "Skip SSL certificate creation (use HTTP only)"
  type        = bool
  default     = false
}

variable "enable_expensive_resources" {
  description = "Enable expensive resources (RDS, ECS, Lambda, Kinesis) for testing"
  type        = bool
  default     = false
}

### Temperature Monitoring Variables ###
variable "temperature_monitoring_bucket_name" {
  description = "S3 bucket name for temperature monitoring data"
  type        = string
  default     = "smarterise-temperature-monitoring"
}

variable "temperature_ftp_host" {
  description = "FTP server hostname for temperature monitoring"
  type        = string
  default     = ""
}

variable "temperature_ftp_user" {
  description = "FTP username for temperature monitoring"
  type        = string
  default     = ""
}

variable "temperature_ftp_pass" {
  description = "FTP password for temperature monitoring"
  type        = string
  sensitive   = true
  default     = ""
}

variable "temperature_ftp_folder" {
  description = "FTP root folder for temperature data"
  type        = string
  default     = "/thermal-data"
}

variable "temperature_site_ids" {
  description = "Comma-separated list of site IDs to monitor"
  type        = string
  default     = "C368,C468"
}

variable "temperature_schedule_expression" {
  description = "EventBridge schedule expression for temperature monitoring"
  type        = string
  default     = "cron(0 * * * ? *)"
}

variable "temperature_schedule_enabled" {
  description = "Whether the temperature monitoring schedule is enabled"
  type        = bool
  default     = true
}

