# Multi-AZ PostgreSQL RDS Cluster Provisioner

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "enterprise-rds-subnet-group"
  subnet_ids = aws_subnet.private_subnets[*].id

  tags = {
    Name        = "Enterprise RDS Subnet Group"
    Environment = "production"
  }
}

resource "aws_db_instance" "postgres_ha" {
  identifier                  = "enterprise-postgres-db"
  allocated_storage           = 100
  max_allocated_storage       = 500
  engine                      = "postgres"
  engine_version              = "15.4"
  instance_class              = "db.r6g.xlarge"
  multi_az                    = true
  db_name                     = "enterprisedb"
  username                    = "dbadmin"
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids      = [aws_security_group.rds_sg.id]
  storage_encrypted           = true
  kms_key_id                  = aws_kms_key.tf_kms_key.arn
  skip_final_snapshot         = false
  final_snapshot_identifier   = "enterprise-db-final-snapshot"

  backup_retention_period = 30
  backup_window           = "03:00-04:00"

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "enterprise-rds-sg"
  description = "Allow inbound PostgreSQL traffic from EKS worker nodes"
  vpc_id      = aws_vpc.production_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
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
