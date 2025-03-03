variable "domain_name" {
  description = "The domain to use for SES (e.g., smarterise.com)"
  type        = string
  default     = "smarterise.com"
}

variable "email1" {
  description = "First email identity (e.g., r.afuye@smarterise.com)"
  type        = string
  default     = "r.afuye@smarterise.com"
}

variable "email2" {
  description = "Second email identity (e.g., tech@smarterise.com)"
  type        = string
  default     = "tech@smarterise.com"
}

variable "email3" {
  description = "Third email identity (e.g., t.falarunu@smarterise.com)"
  type        = string
  default     = "t.falarunu@smarterise.com"
}

variable "configuration_set_name" {
  description = "The name of the SES configuration set"
  type        = string
  default     = "smarterise-config-set"
}
