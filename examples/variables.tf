# =============================================
# General
# =============================================

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  region     = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id

  common_tags = {
    env               = var.env
    terraform_managed = "true"
  }
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
  default     = "password"
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
  type    = string
  default = "awxsecret"
}

variable "awx_admin_username" {
  type    = string
  default = "admin"
}

variable "awx_admin_password" {
  type    = string
  default = "awxpassword"
}

variable "route53_zone_name" {}
