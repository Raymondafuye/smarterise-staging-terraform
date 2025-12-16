variable "rds_postgresql_username" {
  description = "Master username for RDS PostgreSQL instance"
  type        = string
  default     = "dbadmin"
}

variable "public_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "0.0.0.0/0"
}

variable "vpc_ipv6_cidr_block" {
  description = "IPv6 CIDR block for the VPC"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the RDS instance will be deployed"
  type        = string
}
