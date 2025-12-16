variable "datalake_raw_athena_results_storage_bucket_name" {
  description = "name of the bucket for the for results of queries in datalake raw"
  type        = string
}

variable "iot_device_certificate_bucket_name" {
  description = "name of the bucket for the for results of queries in datalake raw"
  type        = string
}

variable "datalake_raw_storage_bucket_name" {
  description = "datalake raw s3 bucket name"
  type        = string
  default     = "smarterise-datalake-raw-dev1"
}

variable "rds_state_bucket_name" {
  description = "name of the bucket to store the RDS state"
  type        = string
}