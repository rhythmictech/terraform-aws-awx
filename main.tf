# =============================================
# AWX Task Role
# =============================================

resource "aws_iam_role" "awx_task_role" {
  name               = "${var.cluster_name}-awx-task-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.task_assume_role_policy_document.json

  # necessary to ensure deletion 
  force_detach_policies = true
}

data "aws_iam_policy_document" "task_assume_role_policy_document" {
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

resource "aws_iam_role_policy_attachment" "execution_role_ec2_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
  role       = aws_iam_role.execution_role.name
}

# =============================================
# Service Discovery
# =============================================

resource "aws_service_discovery_private_dns_namespace" "awx" {
  name = "awx.local"
  vpc  = var.vpc_id
}

# =============================================
# Logs
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
  family                   = var.cluster_name
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
  name            = "${var.cluster_name}-web"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.awx_web.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  depends_on = [
    aws_ecs_cluster.this,
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
    subnets         = var.private_subnets
    security_groups = [aws_security_group.ecs_service_egress.id]
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

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "awx_task" {
  family                   = var.cluster_name
  execution_role_arn       = aws_iam_role.execution_role.arn
  task_role_arn            = aws_iam_role.awx_task_role.arn
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
  name            = "${var.cluster_name}-task"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.awx_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  depends_on = [
    aws_ecs_cluster.this,
    aws_service_discovery_service.awx_task
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

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "awx_queue" {
  family                   = var.cluster_name
  execution_role_arn       = aws_iam_role.execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = 2048
  cpu                      = 1024

  container_definitions = templatefile("${path.module}/templates/queue_service.json", {})

  tags = local.common_tags
}

resource "aws_ecs_service" "awx_queue" {
  name            = "${var.cluster_name}-queue"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.awx_queue.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  depends_on = [
    aws_ecs_cluster.this,
    aws_service_discovery_service.awx_queue
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

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "awx_cache" {
  family                   = var.cluster_name
  execution_role_arn       = aws_iam_role.execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = 2048
  cpu                      = 1024

  container_definitions = templatefile("${path.module}/templates/cache_service.json", {})

  tags = local.common_tags
}

resource "aws_ecs_service" "awx_cache" {
  name            = "${var.cluster_name}-cache"
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.awx_cache.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  depends_on = [
    aws_ecs_cluster.this,
    aws_service_discovery_service.awx_cache
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

resource "aws_ecs_cluster" "this" {
  name = var.cluster_name
  tags = local.common_tags
}
