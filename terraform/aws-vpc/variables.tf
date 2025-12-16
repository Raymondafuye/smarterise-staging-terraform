variable "vpc_cidr_block" {
  description = "CIDR block for VPC"
  type        = string
  default     = "0.0.0.0/0"
}

variable "vpc_name" {
  description = "Name tag for the VPC"
  type        = string
  default     = "main"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
}
