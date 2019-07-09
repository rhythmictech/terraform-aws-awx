# =============================================
# ECS - Task/Service/EC2/ALB
# =============================================

resource "aws_ecs_task_definition" "awx" {
  # the ecs module appends "-cluster" to the name
  family             = "${var.cluster_name}-cluster"
  execution_role_arn = aws_iam_role.execution_role.arn
  container_definitions = templatefile("${path.module}/service/service.json", {
    awx_secret_key_arn     = module.awx_secret_key.secret.arn
    awx_admin_username     = var.awx_admin_username
    awx_admin_password_arn = module.awx_admin_password.secret.arn

    database_username     = var.db_username
    database_password_arn = module.db_password.secret.arn
    database_host         = module.database.this_rds_cluster_endpoint
  })

  volume {
    name = "secrets"
  }

  tags = local.common_tags
}

resource "aws_ecs_service" "awx" {
  # the ecs module appends "-cluster" to the name
  name            = "${var.cluster_name}-cluster"
  cluster         = module.ecs-cluster.cluster-name
  task_definition = aws_ecs_task_definition.awx.arn
  desired_count   = 1
  iam_role        = aws_iam_role.ecs-service-role.arn
  depends_on = [
    aws_iam_role.ecs-service-role,
    module.ecs-cluster
  ]

  load_balancer {
    target_group_arn = aws_lb_target_group.awx.arn
    container_name   = "awxweb"
    container_port   = 8052
  }

  # tags = local.common_tags
}

module "ecs-cluster" {
  source                   = "github.com/rhythmictech/terraform-aws-ecs-cluster?ref=1.0.3"
  name                     = var.cluster_name
  instance_policy_document = data.aws_iam_policy_document.ecs-instance-policy-document.json
  vpc_id                   = var.vpc_id
  alb_subnet_ids           = var.public_subnets
  instance_subnet_ids      = var.private_subnets
  ssh_pubkey               = tls_private_key.ecs_root.public_key_openssh
  instance_type            = var.ecs_instance_type
  region                   = local.region
  min_instances            = var.ecs_min_instances
  max_instances            = var.ecs_max_instances
  desired_instances        = var.ecs_desired_instances

  tags = merge({
    # service = aws_ecs_service.awx.arn
  }, local.common_tags)
}

# ALB

resource "aws_lb_target_group" "awx" {
  name_prefix = substr("${var.cluster_name}-tgtgrp", 0, 6)
  port        = 8052
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    interval            = 10
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "awx" {
  load_balancer_arn = module.ecs-cluster.alb-arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.alb_ssl_certificate_arn
  depends_on        = [aws_lb_target_group.awx]

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.awx.arn
  }
}

resource "aws_lb_listener" "https_redirect" {
  load_balancer_arn = module.ecs-cluster.alb-arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Route 53

data "aws_route53_zone" "zone" {
  name = var.route53_zone_name
}

resource "aws_route53_record" "url" {
  zone_id = data.aws_route53_zone.zone.zone_id
  type    = "A"
  name    = "${var.cluster_name}.${data.aws_route53_zone.zone.name}"

  alias {
    name                   = module.ecs-cluster.alb-dns
    zone_id                = module.ecs-cluster.alb-zone
    evaluate_target_health = false
  }
}

# =============================================
# ECS - IAM/Secrets
# =============================================

# ECS Task Role 

resource "aws_iam_role" "execution_role" {
  name               = "${var.cluster_name}-execution-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.execution_assume_role_policy_document.json
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

# ECS Service Role 

resource "aws_iam_role" "ecs-service-role" {
  name = "${var.cluster_name}-ecs-service-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "ecs-service-role-attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
  role = aws_iam_role.ecs-service-role.name
}

resource "aws_iam_role_policy_attachment" "ecs-service-role-ec2-read-only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
  role = aws_iam_role.ecs-service-role.name
}

resource "aws_iam_role_policy_attachment" "ecs-service-role-route53-read-only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53ReadOnlyAccess"
  role = aws_iam_role.ecs-service-role.name
}

data "aws_iam_policy_document" "ecs-instance-policy-document" {
  statement {
    actions = [
      "rds-db:connect",
    ]

    resources = [
      "arn:aws:rds-db:${local.region}:${local.account_id}:dbuser:${module.database.this_rds_cluster_id}/${module.database.this_rds_cluster_master_username}",
    ]
  }
}

# ECS EC2 Instances Key

resource "tls_private_key" "ecs_root" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "aws_secretsmanager_secret" "ecs_root_ssh_key" {
  name_prefix = "${var.cluster_name}-ssh-key-${var.env}-"
  description = "ssh key for ec2-user user on ECS Instances"

  tags = merge(
    local.common_tags,
    {
      "Name" = "awx-ecs-root-ssh-key"
    },
  )
}

resource "aws_secretsmanager_secret_version" "ecs-root-ssh-key-value" {
  secret_id = aws_secretsmanager_secret.ecs_root_ssh_key.id
  secret_string = tls_private_key.ecs_root.private_key_pem
}

# ECS ALB SSL Cert

resource "aws_lb_listener_certificate" "awx" {
  listener_arn = aws_lb_listener.awx.arn
  certificate_arn = var.alb_ssl_certificate_arn
}

# AWX Component Secrets 

module "db_password" {
  source = "github.com/rhythmictech/terraform-aws-secretsmanager-secret?ref=v0.0.3"

  name = "${var.cluster_name}-db-password"
  description = "RDS password for AWX ECS cluster ${var.cluster_name}"
  value = var.db_password
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

# =============================================
#  RDS
# =============================================

module "database" {
  source = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 2.0"

  name = "${var.cluster_name}-postgres"
  username = var.db_username
  password = var.db_password
  database_name = "awx"

  engine = "aurora-postgresql"
  engine_version = "10.7"

  vpc_id = var.vpc_id
  subnets = var.database_subnets

  allowed_security_groups = [] #TODO
  allowed_security_groups_count = 0 #TODO
  instance_type = var.db_instance_type
  storage_encrypted = true
  apply_immediately = true

  db_parameter_group_name = "default.aurora-postgresql10"
  db_cluster_parameter_group_name = "default.aurora-postgresql10"

  # enabled_cloudwatch_logs_exports = []

  tags = merge({
    # cluster_parameter_group = aws_rds_cluster_parameter_group.default.arn
  }, local.common_tags)
}


# =============================================
#  INGRESS-EGRESSS
# =============================================

resource "aws_security_group_rule" "ecs_alb_ingress_80" {
  security_group_id = module.ecs-cluster.alb-sg-id
  type = "ingress"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ecs_alb_ingress_443" {
  security_group_id = module.ecs-cluster.alb-sg-id
  type = "ingress"
  from_port = 443
  to_port = 443
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ecs_alb_egress" {
  security_group_id = module.ecs-cluster.alb-sg-id
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = [var.cidr_block]
}

resource "aws_security_group_rule" "ecs_ec2_ingress_from_alb" {
  security_group_id = module.ecs-cluster.ec2-sg-id
  type = "ingress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  source_security_group_id = module.ecs-cluster.alb-sg-id
}

resource "aws_security_group_rule" "ecs_ec2_egress" {
  security_group_id = module.ecs-cluster.ec2-sg-id
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "rds_ingress" {
  type = "ingress"
  description = "Allow ECS RDS Communication"
  from_port = 5432
  to_port = 5432
  protocol = "tcp"
  security_group_id = module.database.this_security_group_id
  source_security_group_id = module.ecs-cluster.ec2-sg-id
}
