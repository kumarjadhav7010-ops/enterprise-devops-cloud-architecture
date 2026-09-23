# AWS Aurora Serverless v2 PostgreSQL with pgvector AI Embeddings Terraform Module

resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier      = "enterprise-aurora-serverless-pg"
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"
  engine_version          = "16.2"
  database_name           = "enterprisedb"
  master_username         = "enterprise_admin"
  manage_master_user_password = true
  master_user_secret_kms_key_id = aws_kms_key.tf_kms_key.arn

  db_subnet_group_name    = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.aurora_sg.id]
  storage_encrypted       = true
  kms_key_id              = aws_kms_key.tf_kms_key.arn
  deletion_protection     = true
  skip_final_snapshot     = false
  final_snapshot_identifier = "enterprise-aurora-final-snapshot"

  serverlessv2_scaling_configuration {
    max_capacity = 16.0
    min_capacity = 0.5
  }

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Feature     = "pgvector-embeddings"
  }
}

resource "aws_rds_cluster_instance" "aurora_instances" {
  count               = 2
  identifier          = "enterprise-aurora-instance-${count.index}"
  cluster_identifier  = aws_rds_cluster.aurora_cluster.id
  instance_class      = "db.serverless"
  engine              = aws_rds_cluster.aurora_cluster.engine
  engine_version      = aws_rds_cluster.aurora_cluster.engine_version
  publicly_accessible = false

  monitoring_interval = 15
  monitoring_role_arn = aws_iam_role.rds_monitoring_role.arn
  performance_insights_enabled = true
  performance_insights_retention_period = 731
  performance_insights_kms_key_id = aws_kms_key.tf_kms_key.arn
}

resource "aws_security_group" "aurora_sg" {
  name        = "enterprise-aurora-pg-sg"
  description = "Security group for Aurora Serverless v2 PostgreSQL cluster"
  vpc_id      = aws_vpc.production_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks_sg.id, aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id]
    description     = "Allow PostgreSQL traffic from EKS pods and ECS tasks"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "enterprise-aurora-pg-sg"
  }
}
