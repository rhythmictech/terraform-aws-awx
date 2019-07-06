# =============================================
# ECS - Task/Service/EC2/ALB
# =============================================

variable "cluster-name" {
  default = "awx"
}


data "local_file" "ecs_container_definitions" {
  filename = "${path.module}/service/service.json"
}

resource "aws_ecs_task_definition" "awx" {
  # the ecs module appends "-cluster" to the name
  family                = "${var.cluster-name}-cluster"
  container_definitions = data.local_file.ecs_container_definitions.content

  volume {
    name = "secrets"
  }

  tags = var.tags
}

resource "aws_ecs_service" "awx" {
  # the ecs module appends "-cluster" to the name
  name            = "${var.cluster-name}-cluster"
  cluster         = module.ecs-cluster.cluster-name
  task_definition = aws_ecs_task_definition.awx.arn
  desired_count   = 1
  iam_role        = aws_iam_role.ecs-service-role.arn
  depends_on      = [aws_iam_role.ecs-service-role]

  load_balancer {
    target_group_arn = aws_lb_target_group.awx.arn
    container_name   = "awxweb"
    container_port   = 8052
  }

  tags = var.tags
}

resource "aws_lb_target_group" "awx" {
  name        = "${var.cluster-name}-target-group"
  port        = 8052
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id
}

resource "aws_lb_listener" "awx" {
  load_balancer_arn = module.ecs-cluster.alb-arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.awx.arn
  }
}

module "ecs-cluster" {
  source                   = "github.com/rhythmictech/terraform-aws-ecs-cluster?ref=not-arm"
  name                     = var.cluster-name
  instance_policy_document = data.aws_iam_policy_document.ecs-instance-policy-document.json
  vpc_id                   = var.vpc_id
  alb_subnet_ids           = var.public_subnets
  instance_subnet_ids      = var.private_subnets
  ssh_pubkey               = tls_private_key.ecs_root.public_key_openssh
  instance_type            = "t3.large"
  region                   = local.region
  min_instances            = 2
  max_instances            = 8
  desired_instances        = 2

  tags = var.tags
}

# =============================================
# ECS - IAM/Secrets
# =============================================

resource "tls_private_key" "ecs_root" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_iam_role" "ecs-service-role" {
  name = "awx-ecs"

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
  role = "${aws_iam_role.ecs-service-role.name}"
}

# resource "aws_secretsmanager_secret" "ecs_root_ssh_key" {
#   name_prefix = "awx-ecs-ssh-key-${var.env}-"
#   description = "ssh key for ec2-user user on ECS Instances"

#   tags = merge(
#     var.tags,
#     {
#       "Name" = "awx-ecs-root-ssh-key"
#     },
#   )
# }

# resource "aws_secretsmanager_secret_version" "ecs-root-ssh-key-value" {
#   secret_id     = aws_secretsmanager_secret.ecs_root_ssh_key.id
#   secret_string = tls_private_key.ecs_root.private_key_pem
# }

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

# =============================================
#  RDS
# =============================================

resource "aws_rds_cluster_parameter_group" "default" {
  name = "default"
  family = "aurora-postgresql10"
  description = "RDS default cluster parameter group"
}

module "database" {
  source = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 2.0"

  name = "awx-postgres"
  username = "awx"
  password = "awxpassword"

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

  # enabled_cloudwatch_logs_exports = [
  #   "audit",
  #   "error",
  #   "general",
  #   "slowquery"
  # ]

  tags = var.tags
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
