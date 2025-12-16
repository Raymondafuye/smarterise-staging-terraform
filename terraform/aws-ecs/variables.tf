variable "environment" {
  description = "Environment, such as DEV, PROD etc."
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "region" {
  description = "The region to deploy in"
  type        = string
}

variable "api_image_repository_name" {
  description = "Name of the API Image repository"
  type        = string
}

#variable "private_subnets" {
#  description = "private subnets"
#  type        = list(string)
#}

variable "public_subnets" {
  description = "public subnets"
  type        = list(string)
}

variable "vpc_id" {
  description = "id of the vpc"
  type        = string
}

variable "log_retention_in_days" {
  description = "Log retention in days for this service"
  type        = number
  default     = 3
}

variable "api_service_image_tag" {
  description = "tag for API image"
  type        = string
  default     = "latest"
}

variable "smarterise_domain_root" {
  description = "The root DNS name to use"
  type        = string
}

variable "smarterise_dns_zone_id" {
  type        = string
  description = "The zone ID of the demo dns zone"
}

variable "rds_instance_arn" {
  type        = string
  description = "ARN of the RDS Cluster"
}
variable "rds_credentials_secret_arn" {
  type        = string
  description = "ARN of the RDS Cluster Secrets"
}

variable "rds_connection_string_secret_arn" {
  type        = string
  description = "ARN for RDS connection string secret"
}
