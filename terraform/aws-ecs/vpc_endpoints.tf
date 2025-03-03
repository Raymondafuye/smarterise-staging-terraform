resource "aws_security_group" "vpc_endpoint_sg" {
  name        = "vpc-endpoint-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = "vpc-0f6aed2aca9e9bacb"

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    security_groups  = ["sg-06447d4017012be31"]
  }
}
