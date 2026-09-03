# AWS ElastiCache Redis HA Cluster Terraform Module

resource "aws_elasticache_subnet_group" "redis_subnets" {
  name       = "enterprise-redis-subnet-group"
  subnet_ids = aws_subnet.private_subnets[*].id

  tags = {
    Name        = "Enterprise Redis Subnet Group"
    Environment = "production"
  }
}

resource "aws_elasticache_replication_group" "redis_cluster" {
  replication_group_id          = "enterprise-redis-cluster-prod"
  description                   = "Production High-Availability Redis Replication Group"
  node_type                     = "cache.r6g.large"
  num_cache_clusters            = 3
  port                          = 6379
  parameter_group_name          = "default.redis7"
  automatic_failover_enabled    = true
  multi_az_enabled              = true
  subnet_group_name             = aws_elasticache_subnet_group.redis_subnets.name
  security_group_ids            = [aws_security_group.redis_sg.id]
  at_rest_encryption_enabled    = true
  transit_encryption_enabled    = true
  kms_key_id                    = aws_kms_key.tf_kms_key.arn
  snapshot_retention_limit      = 7
  snapshot_window               = "02:00-03:00"

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

resource "aws_security_group" "redis_sg" {
  name        = "enterprise-redis-sg"
  description = "Allow inbound Redis traffic from EKS worker nodes"
  vpc_id      = aws_vpc.production_vpc.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
