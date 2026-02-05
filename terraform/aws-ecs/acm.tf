# Use existing certificate or skip ACM creation for subdomain
# Since dev.demo.powersmarter.net is a subdomain of demo.powersmarter.net
# which exists in another AWS account, we should either:
# 1. Use an existing certificate ARN
# 2. Skip certificate creation and use ALB without SSL
# 3. Configure proper subdomain delegation

# Only create certificate if no existing ARN is provided
resource "aws_acm_certificate" "ssl_certificate" {
  count                     = var.existing_certificate_arn == null ? 1 : 0
  domain_name               = var.smarterise_domain_root
  subject_alternative_names = ["*.${var.smarterise_domain_root}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Only validate if certificate was created
resource "aws_acm_certificate_validation" "cert_validation" {
  count                   = var.existing_certificate_arn == null ? 1 : 0
  certificate_arn         = aws_acm_certificate.ssl_certificate[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
  
  timeouts {
    create = "10m"
  }
}