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
    "AN54101471"
  ]
}

variable "rds_state_bucket_name" {
  description = "Bucket name to hold RDS State"
  type        = string
  default     = "smarterise-rds-state1"
}
