# =============================================
# General
# =============================================

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  region     = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id

  common_tags = merge({
    env                 = var.env
    terraform_managed   = "true"
    terraform_workspace = terraform.workspace
    Name                = var.cluster_name
    }, var.tags
  )
}

variable "tags" {
  description = "User-Defined tags"
  type        = map(string)
  default     = {}
}

variable "env" {
  description = "environment to tag resources with"
  type        = string
  default     = "default"
}

variable "route53_zone_name" {
  description = "Zone name for Route53 zone to add URL to"
  type        = string
}


# Networking

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "database_subnets" {
  description = "List of subnet IDs where database resides"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "cidr_block" {
  description = "VPC IP block"
  type        = string
}

# DB 

variable "db_instance_type" {
  description = "Instance type used by the Aurora Postgres database"
  type        = "string"
  default     = "db.t3.medium"
}

variable "db_username" {
  description = "Username of DB user which AWX will use"
  default     = "awx"
}

variable "db_password" {
  description = "Password for AWX DB user"
  default     = "Password"
}

# =============================================
# AWX Specific
# =============================================

variable "cluster_name" {
  type    = string
  default = "awx"
}

variable "alb_ssl_certificate_arn" {
  description = "ARN for an SSL certificate stored in Certificate Manager to be used with AWX's ALB"
  type        = string
}

variable "awx_secret_key" {
  description = "secret key for awx, see docs"
  default     = "awxsecret"
}

variable "awx_admin_username" {
  default = "admin"
}

variable "awx_admin_password" {
  default = "awxpassword"
}

# ECS 

variable "ecs_instance_type" {
  description = "Instance type (size) for the EC2 instances which comprise the ECS cluster"
  type        = string
  default     = "t3.medium"
}

variable "ecs_min_instances" {
  default = 2
}

variable "ecs_max_instances" {
  default = 6
}

variable "ecs_desired_instances" {
  default = 2
}

