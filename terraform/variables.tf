variable "datalake_raw_athena_results_storage_bucket_name" {
  description = "name of the bucket for the for results of queries in datalake raw"
  type        = string
  default     = "datalake-raw-athena-results"
}

variable "iot_device_certificate_bucket_name" {
  description = "Bucket name to hold device certificates"
  type        = string
  default     = "smarterise-accuenergy-mqtt-certificates"
}

variable "smarterise_domain_root" {
  description = "The root DNS name to use"
  type        = string
  default     = "demo.powersmarter.net"
}

variable "environment" {
  description = "Environment, such as DEV, PROD etc."
  type        = string
  default     = "dev"
}

variable "datalake_raw_database_name" {
  description = "name of the athena database for datalake raw"
  type        = string
  default     = "datalake_raw"
}

variable "smart_device_names" {
  description = "IoT device names"
  type        = list(string)
  default = [
    "ehm21120333", "an21110124", "an21110075", "an21110071", "dummy_device"
  ]
}

variable "rds_state_bucket_name" {
  description = "Bucket name to hold RDS State"
  type        = string
  default     = "smarterise-rds-state"
}
