# AWS VPC Lattice Service Network & Microservice Mesh Terraform Module

resource "aws_vpclattice_service_network" "enterprise_mesh" {
  name      = "enterprise-service-mesh"
  auth_type = "AWS_IAM"

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Platform    = "VPCLattice"
  }
}

resource "aws_vpclattice_service_network_vpc_association" "prod_vpc_assoc" {
  vpc_identifier             = aws_vpc.production_vpc.id
  service_network_identifier = aws_vpclattice_service_network.enterprise_mesh.id
  security_group_ids         = [aws_security_group.lattice_sg.id]

  tags = {
    Environment = "production"
  }
}

resource "aws_vpclattice_service" "api_lattice_service" {
  name               = "enterprise-backend-api-svc"
  auth_type          = "AWS_IAM"
  custom_domain_name = "api.mesh.enterprise.internal"

  tags = {
    Environment = "production"
    Service     = "BackendAPI"
  }
}

resource "aws_vpclattice_service_network_service_association" "api_mesh_assoc" {
  service_identifier         = aws_vpclattice_service.api_lattice_service.id
  service_network_identifier = aws_vpclattice_service_network.enterprise_mesh.id
}

resource "aws_vpclattice_target_group" "eks_pods_tg" {
  name = "enterprise-api-lattice-tg"
  type = "IP"

  config {
    port             = 8000
    protocol         = "HTTP"
    vpc_identifier   = aws_vpc.production_vpc.id
    ip_address_type  = "IPV4"

    health_check {
      enabled                       = true
      health_check_interval_seconds = 15
      health_check_timeout_seconds  = 5
      healthy_threshold_count       = 2
      unhealthy_threshold_count     = 3
      matcher {
        value = "200"
      }
      path     = "/health/"
      protocol = "HTTP"
    }
  }
}

resource "aws_vpclattice_listener" "api_listener" {
  name               = "enterprise-api-listener"
  service_identifier = aws_vpclattice_service.api_lattice_service.id
  port               = 8000
  protocol           = "HTTP"

  default_action {
    forward {
      target_groups {
        target_group_identifier = aws_vpclattice_target_group.eks_pods_tg.id
        weight                  = 100
      }
    }
  }
}

resource "aws_vpclattice_auth_policy" "mesh_auth_policy" {
  resource_identifier = aws_vpclattice_service.api_lattice_service.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "vpc-lattice-svcs:Invoke"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Resource  = "*"
        Condition = {
          StringEquals = {
            "vpc-lattice-svcs:ServiceNetworkArn" = aws_vpclattice_service_network.enterprise_mesh.arn
          }
        }
      }
    ]
  })
}

resource "aws_security_group" "lattice_sg" {
  name        = "enterprise-vpc-lattice-sg"
  description = "Security group for AWS VPC Lattice Service Network Association"
  vpc_id      = aws_vpc.production_vpc.id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks_sg.id, aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id]
    description     = "Allow Lattice mesh traffic from EKS and ECS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "enterprise-lattice-sg"
  }
}
