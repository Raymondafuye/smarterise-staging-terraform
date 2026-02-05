provider "aws" {
  alias  = "acm_provider"
  region = "us-east-1"
}

# Use existing certificate or skip ACM creation for subdomain
# Only create certificate if no existing ARN is provided
resource "aws_acm_certificate" "ssl_certificate" {
  count                     = var.existing_certificate_arn_us_east_1 == null ? 1 : 0
  provider                  = aws.acm_provider
  domain_name               = var.smarterise_domain_root
  subject_alternative_names = ["*.${var.smarterise_domain_root}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Only validate if certificate was created
resource "aws_acm_certificate_validation" "cert_validation" {
  count                   = var.existing_certificate_arn_us_east_1 == null ? 1 : 0
  provider                = aws.acm_provider
  certificate_arn         = aws_acm_certificate.ssl_certificate[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
  
  timeouts {
    create = "10m"
  }
}