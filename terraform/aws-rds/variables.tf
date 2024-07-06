variable "rds_postgresql_cluster_username" {
  description = "master username for RDS postgresql cluster"
  type        = string
  default     = "dbadmin"
}

variable "private_subnets" {
  description = "private subnets"
  type        = list(string)
}

variable "vpc_cidr_block" {
  description = "cidr block from VPC"
  type        = string
}

variable "vpc_ipv6_cidr_block" {
  description = "IPV6 cidr block from VPC"
  type        = string
}

variable "vpc_id" {
  description = "id from VPC"
  type        = string
}
