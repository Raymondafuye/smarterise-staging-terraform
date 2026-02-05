output "aws_acm_certificate_arn" {
  value = var.existing_certificate_arn_us_east_1 != null ? var.existing_certificate_arn_us_east_1 : (length(aws_acm_certificate.ssl_certificate) > 0 ? aws_acm_certificate.ssl_certificate[0].arn : null)
}