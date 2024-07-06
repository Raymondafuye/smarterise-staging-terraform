output "smarterise_demo_dns_zone_name_servers" {
  value = aws_route53_zone.root_dns_zone.name_servers
}

output "smarterise_demo_dns_zone_id" {
  value = aws_route53_zone.root_dns_zone.zone_id
}