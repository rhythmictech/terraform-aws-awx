# =============================================
# ECS - Task/Service/EC2/ALB
# =============================================

resource "aws_ecs_task_definition" "awx" {
  # the ecs module appends "-cluster" to the name
  family             = "${var.cluster_name}-cluster"
  execution_role_arn = aws_iam_role.execution_role.arn
  container_definitions = templatefile("${path.module}/service.json", {
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

  tags = local.common_tags
}
