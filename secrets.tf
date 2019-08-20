# =============================================
# ECS Task Role 
# =============================================

resource "aws_iam_role" "execution_role" {
  name               = "${var.cluster_name}-execution-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.execution_assume_role_policy_document.json

  # necessary to ensure deletion 
  force_detach_policies = true
}

data "aws_iam_policy_document" "execution_assume_role_policy_document" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "execution_role_attachment" {
  role       = aws_iam_role.execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_role_secrets_policy" {
  statement {
    actions = [
      "ssm:GetParameters",
      "secretsmanager:GetSecretValue",
      "kms:Decrypt"
    ]

    resources = [
      module.db_password.secret.arn,
      module.awx_admin_password.secret.arn,
      module.awx_secret_key.secret.arn
    ]
  }
}

resource "aws_iam_role_policy" "execution_role_secrets_policy" {
  name   = "${var.cluster_name}-execution-role-secrets-policy"
  role   = aws_iam_role.execution_role.id
  policy = data.aws_iam_policy_document.execution_role_secrets_policy.json
}

# =============================================
# ECS ALB SSL Cert
# =============================================

resource "aws_lb_listener_certificate" "awx" {
  listener_arn    = aws_lb_listener.awx.arn
  certificate_arn = var.alb_ssl_certificate_arn
}

# =============================================
# AWX Component Secrets 
# =============================================

module "db_password" {
  source = "github.com/rhythmictech/terraform-aws-secretsmanager-secret?ref=v0.0.3"

  name        = "${var.cluster_name}-db-password"
  description = "RDS password for AWX ECS cluster ${var.cluster_name}"
  value       = module.database.this_rds_cluster_master_password
  tags        = local.common_tags
}

module "awx_secret_key" {
  source = "github.com/rhythmictech/terraform-aws-secretsmanager-secret?ref=v0.0.3"

  name        = "${var.cluster_name}-awx-secret"
  description = "AWX secret for ${var.cluster_name}"
  value       = var.awx_secret_key
  tags        = local.common_tags
}

module "awx_admin_password" {
  source = "github.com/rhythmictech/terraform-aws-secretsmanager-secret?ref=v0.0.3"

  name        = "${var.cluster_name}-awx-password"
  description = "AWX password for ${var.cluster_name}"
  value       = var.awx_admin_password
  tags        = local.common_tags
}
