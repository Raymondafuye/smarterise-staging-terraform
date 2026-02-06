variable "lambda_layer_aws_wrangler_name" {
  description = "Name for the Lambda Layer for AWS Data Wrangler library"
  type        = string
  default     = "python-awswrangler"
}

 variable "lambda_layer_aws_pandas_name"{
  description = "Name for the Lambda Layer for AWS Pandas library"
  type        = string
  default     = "python-pandas"
 }

  variable "lambda_layer_aws_package1_name"{
  description = "Name for the Lambda Layer for AWS Pandas library"
  type        = string
  default     = "package1"
 }


variable "lambda_layer_flattenjson_name" {
  description = "Name for the Lambda Layer for flattenjson library"
  type        = string
  default     = "python-flattenjson"
}

variable "lambda_layer_sqlalchemy_aurora_data_api_name" {
  description = "Name for the Lambda Layer for sqlalchemy aurora data api library"
  type        = string
  default     = "python-sqlalchemy-aurora-data-api"
}

# variable "lambda_layer_catboost_name" {
#   description = "Name for the Lambda Layer for sqlalchemy aurora data api library"
#   type        = string
#   default     = "python-catboost"
# }


variable "smart_device_to_s3_raw_lambda_name" {
  type        = string
  description = "The name for the lambda function that takes data from kinesis to s3 for a smart device"
  default     = "smart-device-kinesis-to-s3"
}

variable "smart_device_to_s3_raw_lambda_function_env_vars" {
  description = "Environment variables for the smart device to s3 raw lambda"
  type        = map(any)
}

variable "device_kinesis_data_stream_name" {
  description = "The name of the Kinesis Data Stream"
  type        = string
  default     = "parsed-device-data-stream"
}

variable "device_kinesis_data_stream_arn" {
  description = "arn for the kinesis data stream that streams data from the smart devices"
  type        = string
  
}

variable "datalake_raw_bucket_arn" {
  description = "arn of the datalake raw bucket"
  type        = string
}

variable "datalake_raw_athena_results_bucket_arn" {
  description = "arn of the datalake raw athena results bucket"
  type        = string
}

variable "parsed_device_kinesis_data_stream_arn" {
  type        = string
  description = "arn for the parsed records coming from the smart meters"
}

variable "smart_device_to_rds_lambda_name" {
  type        = string
  description = "name of the lambda function that takes data from kinesis to RDS"
  default     = "smart-device-to-rds"
}

variable "smart_deivce_to_rds_env_vars" {
  type        = map(string)
  description = "environment variables for smart device to rds lambda"
  default = {}
}

variable "rds_instance_arn" {
  type        = string
  description = "arn of the rds cluster"
}

variable "rds_credentials_secret_arn" {
  type        = string
  description = "arn of the rds cluster secret"
}

variable "schedule_connect_to_aurora_name" {
  type        = string
  description = "name for the aws cloudwatch/event bridge event rule"
  default     = "schedule-connect-to-aurora"
}

variable "connect_to_aurora_lambda_function_env_vars" {
  type        = map(any)
  description = "env vars for the connect to aurora lambda function"
}

#ftp_client connection
variable "rds_endpoint" {
  description = "RDS endpoint"
  type        = string
}

variable "rds_db_name" {
  description = "RDS database name"
  type        = string
}

variable "rds_username" {
  description = "RDS username"
  type        = string
}

variable "rds_password" {
  description = "RDS password"
  type        = string
  sensitive   = true
}

#lambda to ftp_folder

variable "ftp_host" {}
variable "ftp_user" {}
variable "ftp_pass" {}
variable "ftp_folder" {}

variable "s3_folder" {}
variable "s3_bucket" {
  description = "The name of the S3 bucket"
  type        = string
  default     = "ftpfiletest"
}

variable "database_url" {
  description = "The connection string for the RDS database"
  type        = string
}

# Site configuration bucket for enhanced Lambda
variable "site_config_bucket_name" {
  description = "Name of the S3 bucket for site configuration"
  type        = string
  default     = "smarterise-site-config"
}

### Temperature Monitoring Variables ###
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

variable "temperature_s3_bucket" {
  description = "S3 bucket name for temperature monitoring data"
  type        = string
  default     = ""
}

variable "temperature_site_ids" {
  description = "Comma-separated list of site IDs to monitor (e.g., 'C368,C468')"
  type        = string
  default     = "C368,C468"
}

variable "temperature_schedule_expression" {
  description = "EventBridge schedule expression (e.g., 'rate(15 minutes)' or 'cron(0 * * * ? *)')"
  type        = string
  default     = "cron(0 * * * ? *)"
}

variable "temperature_schedule_enabled" {
  description = "Whether the EventBridge schedule is enabled"
  type        = bool
  default     = true
}

