output "vpc_id" {
  value = aws_vpc.this.id
}

#output "private_subnets" {
#  value = aws_subnet.private[*].id
#}

output "public_subnets" {
  value = aws_subnet.public[*].id
}

output "vpc_cidr_block" {
  value = aws_vpc.this.cidr_block
}

output "vpc_ipv6_cidr_block" {
  value = aws_vpc.this.ipv6_cidr_block
}

