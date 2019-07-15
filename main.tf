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
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 5.0.0"
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
  kube_config_path = "${module.eks.kubeconfig_filename}"
  tiller_sa_file   = "${path.module}/templates/tiller-service-account.yaml"
}


resource "null_resource" "install_helm" {
  triggers = {
    build_number = timestamp()
  }
  depends_on = [module.eks]

  provisioner "local-exec" {
    command = <<EOF
    kubectl --kubeconfig ${local.kube_config_path} apply -f ${local.tiller_sa_file}
    helm init --service-account tiller \
      --kubeconfig ${local.kube_config_path} \
    helm repo update
EOF
  }
}

resource "null_resource" "install_nginx" {
  triggers = {
    build_number = timestamp()
  }
  depends_on = [null_resource.install_helm]

  provisioner "local-exec" {
    command = <<EOF
    helm install stable/nginx-ingress \
      --kubeconfig ${local.kube_config_path} \
      --name awx-ingress \
      --set rbac.create=true
EOF
  }
}

resource "null_resource" "install_awx" {
  triggers = {
    build_number = timestamp()
  }
  depends_on = [null_resource.install_nginx]

  provisioner "local-exec" {
    command = <<EOF
    helm repo add rhythmictech https://rhythmictech.github.io/helm-charts/
    helm repo update
    helm install rhythmictech/awx \
      --kubeconfig ${local.kube_config_path} \
      --set ingress.hosts=["${module.eks.cluster_endpoint}"] \
      --set dbHost="${module.database.this_rds_cluster_endpoint}"
EOF
  }
}
