variable "smart_device_names" {
  description = "IoT device names"
  type        = list(string)
}

variable "smart_device_type" {
  description = "type of iot thing"
  type        = string
  default     = "accuenergy_smart_meter"
}

variable "accuenergy_device_group_name" {
  description = "Group name"
  type        = string
  default     = "accuenergy_smart_meters"
}

variable "smart_device_polcy_name" {
  description = "policy name for iot smart devices"
  type        = string
  default     = "smart_device_polcy"
}

###########################################################
# Certificate Bucket
###########################################################
variable "iot_device_certificate_bucket_name" {
  description = "name of the bucket for the for results of queries in datalake raw"
  type        = string
}

###########################################################
# Kinesis
###########################################################
variable "device_data_stream_name" {
  description = "The name of the device data stream"
  type        = string
}
variable "device_data_stream_arn" {
  description = "The ARN of the device data stream"
  type        = string
}
variable "kinesis_kms_key_arn" {
  description = "The ARN of the device data stream KMS key"
  type        = string
}
