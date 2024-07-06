variable "kinesis_device_data_stream_name" {
  description = "kinesis data stream name"
  type        = string
  default     = "device-data-stream"
}

variable "retention_period" {
  description = "Retention period for data"
  type        = number
  default     = 24
}

variable "enforce_consumer_deletion" {
  description = "A boolean that indicates all registered consumers should be deregistered from the stream so that the stream can be destroyed without error"
  type        = bool
  default     = false
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "region_name" {
  description = "AWS region name"
  type        = string
}

variable "deletion_window" {
  description = "Number of days before a key actually gets deleted once it's been scheduled for deletion. Valid value between 7 and 30 days"
  type        = number
  default     = 30
}

variable "parsed_device_data_stream" {
  description = "kinesis data stream name"
  type        = string
  default     = "parsed-device-data-stream"
}