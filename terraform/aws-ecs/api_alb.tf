resource "aws_security_group" "alb_seg" {
  name   = "alb_sg"
  vpc_id = var.vpc_id

  ingress {
    protocol         = "tcp"
    from_port        = 443
    to_port          = 443
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    protocol         = "tcp"
    from_port        = 80
    to_port          = 80
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_lb" "api_load_balancer" {
  name               = "api-load-balancer"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnets
  security_groups    = [aws_security_group.alb_seg.id]
}

resource "aws_lb_target_group" "alb_api_service_tg" {
  name        = "api-sevice-alb-tg"
  target_type = "ip"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id

  health_check {
    healthy_threshold   = "3"
    interval            = "5"
    protocol            = "HTTP"
    port                = 8000
    matcher             = "200"
    timeout             = "3"
    path                = "/health-check"
    unhealthy_threshold = "3"
  }
}


resource "aws_lb_listener" "api_service_lb_listener" {
  load_balancer_arn = aws_lb.api_load_balancer.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.ssl_certificate.arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_api_service_tg.arn
  }
}

resource "aws_lb_listener" "api_service_lb_listener_http_forwarder" {
  load_balancer_arn = aws_lb.api_load_balancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
