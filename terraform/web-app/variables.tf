variable "web_app_bucket_name" {
  description = "Name of the S3 Bucket for the Web App"
  type        = string
  default     = "smarterise-web-app-dev-dev"
}

variable "smarterise_domain_root" {
  description = "The root DNS name to use"
  type        = string
}

variable "smarterise_dns_zone_id" {
  type        = string
  description = "The zone ID of the demo dns zone"
}