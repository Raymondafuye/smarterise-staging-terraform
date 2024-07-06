# Need a new certificate in the local region - the other is for cloudfront and exists only in us-east-1
resource "aws_acm_certificate" "ssl_certificate" {
  domain_name               = var.smarterise_domain_root
  subject_alternative_names = ["*.${var.smarterise_domain_root}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Uncomment the validation_record_fqdns line if you do DNS validation instead of Email.
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.ssl_certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}