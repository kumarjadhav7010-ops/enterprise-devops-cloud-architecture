variable "aws_region" {
  default     = "us-east-1"
  description = "AWS Region for Infrastructure Deployment"
}

variable "environment" {
  default     = "production"
  description = "Target Environment Name"
}

variable "cluster_name" {
  default     = "enterprise-k8s-prod"
  description = "EKS Cluster Identifier"
}

variable "vpc_cidr" {
  default     = "10.100.0.0/16"
  description = "VPC CIDR Block"
}

variable "availability_zones" {
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
  description = "AWS Availability Zones"
}
