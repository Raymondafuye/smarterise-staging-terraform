resource "aws_route53_zone" "root_dns_zone" {
  name = var.smarterise_domain_root
}