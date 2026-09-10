# AWS MSK Serverless Kafka Cluster Terraform Module

resource "aws_msk_serverless_cluster" "enterprise_msk" {
  cluster_name = "enterprise-event-streaming-prod"

  vpc_config {
    subnet_ids         = aws_subnet.private_subnets[*].id
    security_group_ids = [aws_security_group.msk_sg.id]
  }

  client_authentication {
    sasl {
      iam {
        enabled = true
      }
    }
  }

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Platform    = "EventStreaming"
  }
}

resource "aws_security_group" "msk_sg" {
  name        = "enterprise-msk-serverless-sg"
  description = "Security group for AWS MSK Serverless Kafka cluster"
  vpc_id      = aws_vpc.production_vpc.id

  ingress {
    from_port       = 9098
    to_port         = 9098
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id]
    description     = "Allow IAM-authenticated MSK traffic from EKS worker pods"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "enterprise-msk-sg"
  }
}

resource "aws_iam_policy" "msk_producer_consumer_policy" {
  name        = "enterprise-msk-producer-consumer-policy"
  description = "IAM policy granting EKS pods access to MSK Serverless cluster and topics"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:AlterCluster",
          "kafka-cluster:DescribeCluster"
        ]
        Resource = aws_msk_serverless_cluster.enterprise_msk.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:*Topic*",
          "kafka-cluster:WriteData",
          "kafka-cluster:ReadData"
        ]
        Resource = "arn:aws:kafka:${var.aws_region}:${var.aws_account_id}:topic/${aws_msk_serverless_cluster.enterprise_msk.cluster_name}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:AlterGroup",
          "kafka-cluster:DescribeGroup"
        ]
        Resource = "arn:aws:kafka:${var.aws_region}:${var.aws_account_id}:group/${aws_msk_serverless_cluster.enterprise_msk.cluster_name}/*"
      }
    ]
  })
}
