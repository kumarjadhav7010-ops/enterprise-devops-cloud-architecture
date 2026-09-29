# AWS EKS Pod Identity Agent & Least-Privilege Workload IAM Terraform Module

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                = aws_eks_cluster.eks_cluster.name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = "v1.3.0-eksbuild.1"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# IAM Role for KEDA & AI Worker Service Account via EKS Pod Identity
resource "aws_iam_role" "ai_worker_pod_identity_role" {
  name = "enterprise-ai-worker-pod-identity-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEksAuthToAssumeRoleForPodIdentity"
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = {
    Environment = "production"
    Component   = "AI-Worker"
  }
}

resource "aws_iam_policy" "ai_worker_least_privilege_policy" {
  name        = "enterprise-ai-worker-s3-sqs-secrets-policy"
  description = "Least-privilege IAM policy for AI worker pods accessing S3 model registry, SQS queues, and Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ModelArtifactsReadOnly"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::enterprise-model-weights-prod",
          "arn:aws:s3:::enterprise-model-weights-prod/*"
        ]
      },
      {
        Sid    = "SQSInferenceQueueConsumer"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = "arn:aws:sqs:${var.aws_region}:${var.aws_account_id}:enterprise-inference-jobs-queue"
      },
      {
        Sid    = "SecretsManagerReadProductionKeys"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:production/*"
      },
      {
        Sid    = "KMSDecryptSecretsAndArtifacts"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.tf_kms_key.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ai_worker_policy_attach" {
  role       = aws_iam_role.ai_worker_pod_identity_role.name
  policy_arn = aws_iam_policy.ai_worker_least_privilege_policy.arn
}

resource "aws_eks_pod_identity_association" "ai_worker_association" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  namespace       = "production-apps"
  service_account = "celery-ai-worker-sa"
  role_arn        = aws_iam_role.ai_worker_pod_identity_role.arn

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
