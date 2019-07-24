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

resource "aws_iam_role_policy_attachment" "execution_role_ec2_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
  role = aws_iam_role.execution_role.name
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
# ECS Service Role 
# =============================================

# resource "aws_iam_role" "ecs-service-role" {
#   name = "${var.cluster_name}-ecs-service-role"

#   # necessary to ensure deletion 
#   force_detach_policies = true

#   assume_role_policy = <<POLICY
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Service": "ecs.amazonaws.com"
#       },
#       "Action": "sts:AssumeRole"
#     }
#   ]
# }
# POLICY
# }

# resource "aws_iam_role_policy_attachment" "ecs-container-service-role-attachment" {
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
#   role = aws_iam_role.ecs-service-role.name
# }

# resource "aws_iam_role_policy_attachment" "ecs-elb-read-role-attachment" {
#   policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingReadOnly"
#   role = aws_iam_role.ecs-service-role.name
# }

# resource "aws_iam_role_policy_attachment" "ecs-service-role-ec2-read-only" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
#   role = aws_iam_role.ecs-service-role.name
# }

# resource "aws_iam_role_policy_attachment" "ecs-service-role-route53-read-only" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53ReadOnlyAccess"
#   role = aws_iam_role.ecs-service-role.name
# }

# data "aws_iam_policy_document" "ecs-instance-policy-document" {
#   statement {
#     actions = [
#       "rds-db:connect",
#     ]

#     resources = [
#       "arn:aws:rds-db:${local.region}:${local.account_id}:dbuser:${module.database.this_rds_cluster_id}/${module.database.this_rds_cluster_master_username}",
#     ]
#   }
# }

# =============================================
# ECS ALB SSL Cert
# =============================================

resource "aws_lb_listener_certificate" "awx" {
  listener_arn = aws_lb_listener.awx.arn
  certificate_arn = var.alb_ssl_certificate_arn
}

# =============================================
# AWX Component Secrets 
# =============================================

module "db_password" {
  source = "github.com/rhythmictech/terraform-aws-secretsmanager-secret?ref=v0.0.3"

  name = "${var.cluster_name}-db-password"
  description = "RDS password for AWX ECS cluster ${var.cluster_name}"
  value = module.database.this_rds_cluster_master_password
  tags = local.common_tags
}

module "awx_secret_key" {
  source = "github.com/rhythmictech/terraform-aws-secretsmanager-secret?ref=v0.0.3"

  name = "${var.cluster_name}-awx-secret"
  description = "AWX secret for ${var.cluster_name}"
  value = var.awx_secret_key
  tags = local.common_tags
}

module "awx_admin_password" {
  source = "github.com/rhythmictech/terraform-aws-secretsmanager-secret?ref=v0.0.3"

  name = "${var.cluster_name}-awx-password"
  description = "AWX password for ${var.cluster_name}"
  value = var.awx_admin_password
  tags = local.common_tags
}
