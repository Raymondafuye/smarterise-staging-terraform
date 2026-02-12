variable "site_config_bucket_name" {
  description = "Name of the S3 bucket for site configuration"
  type        = string
}

variable "smart_device_names" {
  description = "List of smart device names"
  type        = list(string)
}

variable "device_data_stream_name" {
  description = "Name of the Kinesis data stream"
  type        = string
  default     = ""
}

variable "iot_kinesis_role_arn" {
  description = "ARN of the IAM role for IoT to write to Kinesis"
  type        = string
  default     = ""
}