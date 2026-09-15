# AWS App Runner Managed Container Service & Auto-Scaling Terraform Module

resource "aws_apprunner_auto_scaling_configuration_version" "api_auto_scaling" {
  auto_scaling_configuration_name = "enterprise-api-auto-scaling"

  max_concurrency = 100
  max_size        = 15
  min_size        = 2

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

resource "aws_apprunner_vpc_connector" "connector" {
  vpc_connector_name = "enterprise-apprunner-vpc-connector"
  subnets            = aws_subnet.private_subnets[*].id
  security_groups    = [aws_security_group.apprunner_sg.id]
}

resource "aws_apprunner_service" "enterprise_api" {
  service_name                   = "enterprise-microservice-runner"
  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.api_auto_scaling.arn

  source_configuration {
    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_ecr_access_role.arn
    }

    image_repository {
      image_identifier      = "${aws_ecr_repository.api_repo.repository_url}:v2.4.0"
      image_repository_type = "ECR"

      image_configuration {
        port = "8000"
        runtime_environment_variables = {
          ENVIRONMENT = "production"
          LOG_LEVEL   = "info"
        }
        runtime_environment_secrets = {
          DATABASE_URL = aws_secretsmanager_secret.db_url.arn
          REDIS_URL    = aws_secretsmanager_secret.redis_url.arn
        }
      }
    }

    auto_deployments_enabled = true
  }

  network_configuration {
    egress_configuration {
      egress_type       = "VPC"
      vpc_connector_arn = aws_apprunner_vpc_connector.connector.arn
    }
  }

  instance_configuration {
    cpu    = "1024"
    memory = "2048"
    instance_role_arn = aws_iam_role.apprunner_instance_role.arn
  }

  health_check_configuration {
    protocol            = "HTTP"
    path                = "/health/"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

resource "aws_security_group" "apprunner_sg" {
  name        = "enterprise-apprunner-sg"
  description = "Security group for App Runner VPC connector"
  vpc_id      = aws_vpc.production_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "enterprise-apprunner-sg"
  }
}
