terraform {
  required_version = ">= 0.12.0"
}

data "aws_availability_zones" "available" {}

# =============================================
# Security Groups 
# =============================================

resource "aws_security_group" "worker_group_mgmt_one" {
  name_prefix = "worker_group_mgmt_one"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }
}

resource "aws_security_group" "worker_group_mgmt_two" {
  name_prefix = "worker_group_mgmt_two"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "192.168.0.0/16",
    ]
  }
}

resource "aws_security_group" "all_worker_mgmt" {
  name_prefix = "all_worker_management"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }
}

# =============================================
# RDS
# =============================================

module "database" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 2.0"

  name          = "${var.cluster_name}-postgres"
  username      = var.db_username
  password      = var.db_password
  database_name = "awx"

  engine         = "aurora-postgresql"
  engine_version = "10.7"
  engine_mode    = "serverless"

  vpc_id  = var.vpc_id
  subnets = var.database_subnets

  allowed_security_groups       = [module.eks.worker_security_group_id]
  allowed_security_groups_count = 1
  instance_type                 = var.db_instance_type
  replica_count                 = 0
  storage_encrypted             = true
  apply_immediately             = true

  db_parameter_group_name         = "default.aurora-postgresql10"
  db_cluster_parameter_group_name = "default.aurora-postgresql10"

  tags = local.common_tags
}

# =============================================
# EKS Cluster
# =============================================

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 5.0.0"

  cluster_name    = var.cluster_name
  subnets         = var.public_subnets
  vpc_id          = var.vpc_id
  cluster_version = "1.13"

  worker_groups = [
    {
      name                          = "worker-group-1"
      instance_type                 = "t3.small"
      additional_userdata           = "echo foo bar"
      asg_desired_capacity          = 3
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
      # tags = merge(local.common_tags, {
      #   propagate_at_launch = true
      # })
    },
  ]

  worker_additional_security_group_ids = [aws_security_group.all_worker_mgmt.id]

  tags = local.common_tags
}

output "eks" {
  value = module.eks
}

# =============================================
# Helm - AWX
# =============================================

locals {
  kube_config_path = "${path.root}/${module.eks.kubeconfig_filename}"
}

# =============================================
# K8s
# =============================================

provider "kubernetes" {
  version     = "~> 1.8.0"
  config_path = local.kube_config_path
}

# =============================================
# K8s Secrets 
# =============================================

resource "kubernetes_secret" "dbpassword" {
  metadata {
    name = "dbpassword"
  }

  data = {
    password = module.database.this_rds_cluster_master_password
  }
}

# =============================================
# K8s Services & Deployments 
# =============================================

locals {
  nginx_name     = "${var.cluster_name}-nginx"
  rabbitmq_name  = "${var.cluster_name}-rabbitmq"
  memcached_name = "${var.cluster_name}-memcached"
  awx_web_name   = "${var.cluster_name}-awx-web"
  awx_task_name  = "${var.cluster_name}-awx-task"

  common_labels = {
    app = var.cluster_name
  }

  nginx_labels = merge(local.common_labels, {
    component = "nginx"
    name      = local.nginx_name
  })

  rabbitmq_labels = merge(local.common_labels, {
    component = "rabbitmq"
    name      = local.rabbitmq_name
  })
  rabbitmq_env = {
    RABBITMQ_DEFAULT_VHOST = "awx"
    RABBITMQ_DEFAULT_USER  = "guest"
    RABBITMQ_DEFAULT_PASS  = "awxpass"
    RABBITMQ_ERLANG_COOKIE = "cockiemonster"
  }

  memcached_labels = merge(local.common_labels, {
    component = "memcached"
    name      = local.memcached_name
  })
  
  awx_web_labels = merge(local.common_labels, {
    component = "awx-web"
    name      = local.awx_web_name
  })
  
  awx_task_labels = merge(local.common_labels, {
    component = "awx-task"
    name      = local.awx_task_name
  })

  awx_env = merge(local.rabbitmq_env, {
    DATABASE_HOST = module.database.this_rds_cluster_endpoint
    DATABASE_USER = var.db_username
    DATABASE_PASSWORD = var.db_password
    DATABASE_NAME = "awx"
    RABBITMQ_HOST = "awx-rabbitmq"
    MEMCACHED_HOST = "awx-memcached"
    SECRET_KEY = "awxsecret"
    AWX_ADMIN_USER="admin"
    AWX_ADMIN_PASSWORD="awxpassword"
  })
}

# RDS External Name 
resource "kubernetes_service" "rds_external_service" {
  metadata {
    name = "rds-external-service"
    labels = merge(local.common_labels, {
      component = "db"
      name      = "${var.cluster_name}-postgres"
    })
  }
  spec {
    type          = "ExternalName"
    external_name = module.database.this_rds_cluster_endpoint
  }
}


# nginx
resource "kubernetes_ingress" "nginx" {
  metadata {
    name = local.nginx_name
  }
  spec {
    rule {
      # host = replace(module.eks.cluster_endpoint, "https://", "")
      http {
        path {
          path = "/"
          backend {
            service_name = local.awx_web_name
            service_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "nginx" {
  metadata {
    name   = local.nginx_name
    labels = local.nginx_labels
  }
  spec {
    selector = local.nginx_labels
    port {
      port        = 8080
      target_port = 80
    }
  }
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name   = local.nginx_name
    labels = local.nginx_labels
  }
  spec {
    replicas = 1
    selector {
      match_labels = local.nginx_labels
    }
    template {
      metadata {
        labels = local.nginx_labels
      }
      spec {
        container {
          image = "nginx:1.7.8"
          name  = local.nginx_name
        }
      }
    }
  }
}

# rabbitmq
resource "kubernetes_service" "rabbitmq" {
  metadata {
    name = "${var.cluster_name}-rabbitmq"
    labels = {
      app       = var.cluster_name
      component = "rabbitmq"
    }
  }
  spec {
    selector = {
      app       = var.cluster_name
      component = "rabbitmq"
    }
    port {
      port = 5672
    }
  }
}
resource "kubernetes_deployment" "rabbitmq" {
  metadata {
    name   = local.rabbitmq_name
    labels = local.rabbitmq_labels
  }
  spec {
    replicas = 1
    selector {
      match_labels = local.rabbitmq_labels
    }
    template {
      metadata {
        labels = local.rabbitmq_labels
      }
      spec {
        container {
          image = "rabbitmq:3"
          name  = local.rabbitmq_name

          dynamic "env" {
            for_each = local.rabbitmq_env
            content {
              name  = env.key
              value = env.value
            }
          }
        }
      }
    }
  }
}

# cache (memcached)
resource "kubernetes_service" "memcached" {
  metadata {
    name   = local.memcached_name
    labels = local.memcached_labels
  }
  spec {
    selector = local.memcached_labels
    port {
      port = 11211
    }
  }
}
resource "kubernetes_deployment" "memcached" {
  metadata {
    name   = local.memcached_name
    labels = local.memcached_labels
  }
  spec {
    replicas = 1
    selector {
      match_labels = local.memcached_labels
    }
    template {
      metadata {
        labels = local.memcached_labels
      }
      spec {
        container {
          image = "memcached:alpine"
          name  = local.memcached_name
        }
      }
    }
  }
}

# awx_task 
resource "kubernetes_deployment" "awx_task" {
  metadata {
    name = local.awx_task_name
    labels = local.awx_task_labels
  }
  spec {
    selector {
      match_labels = local.awx_task_labels
    }
    template {
      metadata {
        labels = local.awx_task_labels
      }
      spec {
        container {
          image = "sblack4/awx_task:v6-b3"
          name = local.awx_task_name
          dynamic "env" {
            for_each = local.awx_env
            content {
              name  = env.key
              value = env.value
            }
          }
        }
      }
    }
  }
}

# awx web 
resource "kubernetes_service" "awx_web" {
  metadata {
    name   = local.awx_web_name
    labels = local.awx_web_labels
  }
  spec {
    selector = local.awx_web_labels
    type     = "NodePort"
    port {
      name = local.awx_web_name
      port = 80
      target_port = 8052
    }
  }
}
resource "kubernetes_deployment" "awx_web" {
  metadata {
    name = local.awx_web_name
    labels = local.awx_web_labels
  }
  spec {
    selector {
      match_labels = local.awx_web_labels
    }
    template {
      metadata {
        labels = local.awx_web_labels
      }
      spec {
        container {
          image = "sblack4/awx_web:v6-b3"
          name = local.awx_web_name
          port {
            name = local.awx_web_name
            container_port = 8052
          }
          dynamic "env" {
            for_each = local.awx_env
            content {
              name  = env.key
              value = env.value
            }
          }
        }
      }
    }
  }
}