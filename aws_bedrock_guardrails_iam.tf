# AWS Bedrock GenAI Guardrails & Workload IAM Terraform Module

resource "aws_bedrock_guardrail" "enterprise_ai_guardrail" {
  name                      = "enterprise-production-ai-guardrail"
  description               = "Zero-trust AI safety guardrail for LLM inference microservices"
  blocked_input_messaging   = "Request flagged: Input violates enterprise AI governance safety policies."
  blocked_outputs_messaging = "Response redacted: Output violates enterprise AI compliance policies."

  content_policy_config {
    filters_config {
      type            = "HATE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "INSULTS"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "SEXUAL"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "VIOLENCE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "PROMPT_ATTACK"
      input_strength  = "HIGH"
      output_strength = "NONE"
    }
  }

  sensitive_information_policy_config {
    pii_entities_config {
      type   = "CREDIT_DEBIT_CARD_NUMBER"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "EMAIL"
      action = "ANONYMIZE"
    }
    pii_entities_config {
      type   = "AWS_ACCESS_KEY"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "AWS_SECRET_KEY"
      action = "BLOCK"
    }
  }

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Workload    = "GenerativeAI"
  }
}

resource "aws_bedrock_guardrail_version" "guardrail_v1" {
  guardrail_arn = aws_bedrock_guardrail.enterprise_ai_guardrail.guardrail_arn
  description   = "Production baseline guardrail version v1"
}

# IAM Role for EKS AI Inference Pods (IRSA)
resource "aws_iam_role" "eks_ai_workload_role" {
  name = "enterprise-eks-ai-inference-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${var.aws_account_id}:oidc-provider/${replace(aws_eks_cluster.eks_cluster.endpoint, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.eks_cluster.endpoint, "https://", "")}:sub" = "system:serviceaccount:production-apps:ai-inference-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "bedrock_invoke_policy" {
  name        = "enterprise-bedrock-invoke-policy"
  description = "Allows EKS AI pods to invoke Bedrock foundation models through Guardrails"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
          "bedrock:ApplyGuardrail"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/*",
          aws_bedrock_guardrail.enterprise_ai_guardrail.guardrail_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ai_workload_attach" {
  role       = aws_iam_role.eks_ai_workload_role.name
  policy_arn = aws_iam_policy.bedrock_invoke_policy.arn
}
