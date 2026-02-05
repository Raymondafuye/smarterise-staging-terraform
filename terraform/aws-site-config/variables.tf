variable "site_config_bucket_name" {
  description = "Name of the S3 bucket for site configuration"
  type        = string
}

variable "smart_device_names" {
  description = "List of smart device names"
  type        = list(string)
}