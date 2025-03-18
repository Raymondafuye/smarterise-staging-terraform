# Prepare a CloudWatch log group for this service
resource "aws_cloudwatch_log_group" "api_service_log_group" {
  name              = "/${var.environment}/ecs/api_service"
  retention_in_days = var.log_retention_in_days
}

resource "aws_security_group" "api_service_sg" {
  name   = "api_service_sg"
  vpc_id = var.vpc_id

  ingress = [ # in
    {         # 
      description      = "Allow 80 from ALB"
      from_port        = 8000
      to_port          = 8000
      protocol         = "tcp"
      cidr_blocks      = []
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = [aws_security_group.alb_seg.id]
      self             = false
    },
  ]

  # Allow all egress
  egress = [
  {
    description      = "Allow all egress"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }
]
}


resource "aws_ecs_service" "api_service" {
  name                 = "api_service"
  cluster              = aws_ecs_cluster.main.arn
  task_definition      = aws_ecs_task_definition.api_service_task_definition.arn
  desired_count        = 1
  force_new_deployment = true

  load_balancer {
    target_group_arn = aws_lb_target_group.alb_api_service_tg.arn
    container_name   = "api_service"
    container_port   = 8000
  }

  launch_type = "FARGATE"
  network_configuration {
    subnets          = [var.public_subnets[0]]
    security_groups  = [aws_security_group.api_service_sg.id]
    assign_public_ip = true
  }
}

resource "aws_ecs_task_definition" "api_service_task_definition" {
  family                   = "api_service_${var.environment}"
  cpu                      = 512
  memory                   = 1024
  network_mode             = "awsvpc"
  task_role_arn            = "arn:aws:iam::${var.aws_account_id}:role/ecsTaskExecutionRole${var.environment}"
  execution_role_arn       = "arn:aws:iam::${var.aws_account_id}:role/ecsTaskExecutionRole${var.environment}"
  requires_compatibilities = ["FARGATE"]

  container_definitions = jsonencode([
    {
      name      = "api_service"
      image     = "${var.aws_account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.api_image_repository_name}:${var.api_service_image_tag}"
      essential = true
      cpu       = 256

      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api_service_log_group.name
          "awslogs-region"        = var.region,
          "awslogs-stream-prefix" = "ecs"
        }
      },
    "environment": [
                {
                    "name": "AUTH0_CLIENT_SECRET",
                    "value": "bRnKn_YngcUU3B-rJr9M7YpcH-0KXYLthU0uFczQnnjY2RuWeFLr-j3GYAp-HbRa"
                },
                {
                    "name": "AWS_ARN_RESOURCE",
                    "value": "arn:aws:rds:eu-west-2:794038252750:db:postgresql-instance"
                },
                {
                    "name": "AWS_SECRET_ACCESS_KEY",
                    "value": "4l5+xPX8eOd/2y2zc/xQHxBx6sqv8w53ZUo+BjFT"
                },
                {
                    "name": "AWS_DEFAULT_REGION",
                    "value": "eu-west-2"
                },
                {
                    "name": "DJANGO_DEBUG",
                    "value": "true"
                },
                {
                    "name": "AUTH0_DOMAIN",
                    "value": "dev-mgw72jpas4obd84e.us.auth0.com"
                },
                {
                    "name": "DJANGO_CORS_ALLOW_ALL_ORIGINS",
                    "value": "True"
                },
                {
                    "name": "DJANGO_SETTINGS_MODULE",
                    "value": "main.development.settings"
                },
                {
                    "name": "DJANGOENV",
                    "value": "development"
                },
                {
                    "name": "AUTH0_CLIENT_ID",
                    "value": "C0NFrNh6Ur774Zxu3l8fHDwWZSAf5CEA"
                },
                {
                    "name": "DJANGO_ALLOWED_HOSTS",
                    "value": "*"
                },
                {
                    "name": "API_IDENTIFIER",
                    "value": "https://api.dev.demo.powersmarter.net/"
                },
                {
                    "name": "AWS_ACCESS_KEY_ID",
                    "value": "AKIA3RYC6GTHC5CLYKVT"
                },
                {
                    "name": "AWS_SECRET_ARN",
                    "value": "arn:aws:secretsmanager:eu-west-2:794038252750:secret:rds-credentials-postgresql-instance-lkvYFL"
                },
                {
                    "name": "AWS_RDS_DATABASE",
                    "value": "smartmeters"
                }
            ],
      secrets = [
  {
    name      = "DJANGO_DEFAULT_DATABASE"
    valueFrom = "${var.rds_connection_string_secret_arn}:connection_string::"
  }
]
    }
    ]
  )
}

