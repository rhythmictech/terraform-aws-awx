terraform {
  required_version = ">= 0.12.0"
}

data "aws_availability_zones" "available" {
}

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

# # =============================================
# # New VPC 
# # =============================================

# module "vpc" {
#   source  = "terraform-aws-modules/vpc/aws"
#   version = "2.6.0"

#   name               = "test-vpc"
#   cidr               = "10.0.0.0/16"
#   azs                = data.aws_availability_zones.available.names
#   private_subnets    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
#   public_subnets     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
#   enable_nat_gateway = true
#   single_nat_gateway = true

#   tags = merge({
#     "kubernetes.io/cluster/${var.cluster_name}" = "shared"
#   }, local.common_tags)

#   public_subnet_tags = merge({
#     "kubernetes.io/cluster/${var.cluster_name}" = "shared"
#   }, local.common_tags)

#   private_subnet_tags = merge({
#     "kubernetes.io/cluster/${var.cluster_name}" = "shared"
#     "kubernetes.io/role/internal-elb"             = "true"
#   }, local.common_tags)
# }

# =============================================
# EKS Cluster
# =============================================

module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  cluster_name = var.cluster_name
  subnets      = var.public_subnets
  vpc_id       = var.vpc_id

  worker_groups = [
    {
      name                          = "worker-group-1"
      instance_type                 = "t3.small"
      additional_userdata           = "echo foo bar"
      asg_desired_capacity          = 3
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id],
      tags = merge(local.common_tags, {
        propagate_at_launch = true
      })
    },
  ]

  worker_additional_security_group_ids = [aws_security_group.all_worker_mgmt.id]
  # map_roles                            = var.map_roles
  # map_users                            = var.map_users
  # map_accounts                         = var.map_accounts

  tags = local.common_tags
}

output "eks" {
  value = module.eks
}


# =============================================
# Helm
# =============================================

provider "helm" {
  kubernetes {
    config_path = "${path.root}/${module.eks.kubeconfig_filename}"

    # host                   = module.eks.cluster_endpoint
    # token                  = module.eks. "${data.google_client_config.current.access_token}"
    # client_certificate     = "${base64decode(google_container_cluster.default.master_auth.0.client_certificate)}"
    # client_key             = "${base64decode(google_container_cluster.default.master_auth.0.client_key)}"
    # cluster_ca_certificate = module.eks.cluster_certificate_authority_data
  }
}

data "helm_repository" "rhythmic" {
  name = "rhythmic"
  url  = "https://rhythmictech.github.io/helm-charts/"
}

# resource "helm_release" "nginx" {

# }


# resource "helm_release" "awx" {
#   name = "awx"
#   repository = data.helm_repository.stable.metadata.0.name
#   chart = "awx"
#   version = "0.0.4"

#   set {
#     name = "ingress.hosts"
#     value = [

#     ]
#   }
# }
