# =============================================
# Service Discovery
# =============================================

resource "aws_service_discovery_private_dns_namespace" "awx" {
  name = "awx.local"
  vpc  = var.vpc_id
}

# =============================================
# Set up Logs 
# =============================================

resource "aws_cloudwatch_log_group" "ecs" {
  name = "/ecs/fargate-task-definition"

  tags = local.common_tags
}

# =============================================
# ECS - AWX Web
# =============================================

resource "aws_service_discovery_service" "awx_web" {
  name = "awxweb"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.awx.id

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "awx_web" {
  family                   = module.ecs-cluster.cluster-name
  execution_role_arn       = aws_iam_role.execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = 2048
  cpu                      = 1024

  container_definitions = templatefile("${path.module}/templates/web_service.json", {
    awx_secret_key_arn     = module.awx_secret_key.secret.arn
    awx_admin_username     = var.awx_admin_username
    awx_admin_password_arn = module.awx_admin_password.secret.arn

    database_username     = var.db_username
    database_password_arn = module.db_password.secret.arn
    database_host         = module.database.this_rds_cluster_endpoint
  })

  tags = local.common_tags
}

resource "aws_ecs_service" "awx_web" {
  name            = "${module.ecs-cluster.cluster-name}-web"
  cluster         = module.ecs-cluster.cluster-name
  task_definition = aws_ecs_task_definition.awx_web.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  depends_on = [
    aws_iam_role.ecs-service-role,
    module.ecs-cluster.cluster-name,
    aws_service_discovery_service.awx_web
  ]

  load_balancer {
    target_group_arn = aws_lb_target_group.awx.arn
    container_name   = "awxweb"
    container_port   = 8052
  }

  service_registries {
    registry_arn = aws_service_discovery_service.awx_web.arn
  }

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [aws_security_group.ecs_service_egress.id]
  }
}

# =============================================
# ECS - AWX Task
# =============================================

resource "aws_service_discovery_service" "awx_task" {
  name = "awx"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.awx.id
    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}

resource "aws_ecs_task_definition" "awx_task" {
  family                   = module.ecs-cluster.cluster-name
  execution_role_arn       = aws_iam_role.execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = 4096
  cpu                      = 2048

  container_definitions = templatefile("${path.module}/templates/task_service.json", {
    awx_secret_key_arn     = module.awx_secret_key.secret.arn
    awx_admin_username     = var.awx_admin_username
    awx_admin_password_arn = module.awx_admin_password.secret.arn

    database_username     = var.db_username
    database_password_arn = module.db_password.secret.arn
    database_host         = module.database.this_rds_cluster_endpoint
  })

  tags = local.common_tags
}

resource "aws_ecs_service" "awx_task" {
  name            = "${module.ecs-cluster.cluster-name}-task"
  cluster         = module.ecs-cluster.cluster-name
  task_definition = aws_ecs_task_definition.awx_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  depends_on = [
    aws_iam_role.ecs-service-role,
    module.ecs-cluster.cluster-name
  ]

  service_registries {
    registry_arn = aws_service_discovery_service.awx_task.arn
  }

  network_configuration {
    subnets         = var.private_subnets
    security_groups = [aws_security_group.ecs_service_egress.id]
  }
}

# =============================================
# ECS - AWX Queue (rabbitmq)
# =============================================

resource "aws_service_discovery_service" "awx_queue" {
  name = "rabbitmq"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.awx.id
    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}

resource "aws_ecs_task_definition" "awx_queue" {
  family                   = module.ecs-cluster.cluster-name
  execution_role_arn       = aws_iam_role.execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = 2048
  cpu                      = 1024

  container_definitions = templatefile("${path.module}/templates/queue_service.json", {})

  tags = local.common_tags
}

resource "aws_ecs_service" "awx_queue" {
  name            = "${module.ecs-cluster.cluster-name}-queue"
  cluster         = module.ecs-cluster.cluster-name
  task_definition = aws_ecs_task_definition.awx_queue.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  depends_on = [
    aws_iam_role.ecs-service-role,
    module.ecs-cluster.cluster-name
  ]

  service_registries {
    registry_arn = aws_service_discovery_service.awx_queue.arn
  }

  network_configuration {
    subnets         = var.private_subnets
    security_groups = [aws_security_group.ecs_service_egress.id]
  }
}

# =============================================
# ECS - AWX Cache (memcached)
# =============================================

resource "aws_service_discovery_service" "awx_cache" {
  name = "memcached"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.awx.id
    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}

resource "aws_ecs_task_definition" "awx_cache" {
  family                   = module.ecs-cluster.cluster-name
  execution_role_arn       = aws_iam_role.execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = 2048
  cpu                      = 1024

  container_definitions = templatefile("${path.module}/templates/cache_service.json", {})

  tags = local.common_tags
}

resource "aws_ecs_service" "awx_cache" {
  name            = "${module.ecs-cluster.cluster-name}-cache"
  cluster         = module.ecs-cluster.cluster-name
  task_definition = aws_ecs_task_definition.awx_cache.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  depends_on = [
    aws_iam_role.ecs-service-role,
    module.ecs-cluster.cluster-name
  ]

  service_registries {
    registry_arn = aws_service_discovery_service.awx_cache.arn
  }

  network_configuration {
    subnets         = var.private_subnets
    security_groups = [aws_security_group.ecs_service_egress.id]
  }
}


# =============================================
# ECS Cluster 
# =============================================

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
  min_instances            = 0
  max_instances            = 0
  desired_instances        = 0

  tags = local.common_tags
}
