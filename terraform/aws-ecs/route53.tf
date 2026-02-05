resource "aws_route53_record" "root-a" {
  zone_id = var.smarterise_dns_zone_id
  name    = "api.${var.smarterise_domain_root}"
  type    = "A"

  alias {
    name                   = aws_lb.api_load_balancer.dns_name
    zone_id                = aws_lb.api_load_balancer.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = var.existing_certificate_arn == null && length(aws_acm_certificate.ssl_certificate) > 0 ? {
    for dvo in aws_acm_certificate.ssl_certificate[0].domain_validation_options : dvo.domain_name => {
      name    = dvo.resource_record_name
      record  = dvo.resource_record_value
      type    = dvo.resource_record_type
      zone_id = var.smarterise_dns_zone_id
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = each.value.zone_id
}