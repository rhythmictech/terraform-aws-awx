provider "aws" {
  region = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "awx"
}

variable "db_instance_type" {
  description = "Instance type used by the Aurora Postgres database"
  type        = "string"
  default     = "db.t3.medium"
}

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "cidr_block" {
  description = "VPC IP block"
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

variable "alb_ssl_certificate_arn" {
  description = "ARN for an SSL certificate stored in Certificate Manager to be used with AWX's ALB"
  type        = string
}

variable "route53_zone_name" {
  description = "Name of Route53 Zone in which to put AWX Deployment"
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


variable "tags" {
  description = "User-Defined tags"
  type        = map(string)
  default     = {}
}

module "awx" {
  source = "../"

  cluster_name            = var.cluster_name
  awx_secret_key          = var.awx_secret_key
  awx_admin_username      = var.awx_admin_username
  awx_admin_password      = var.awx_admin_password
  db_instance_type        = var.db_instance_type
  vpc_id                  = var.vpc_id
  cidr_block              = var.cidr_block
  database_subnets        = var.database_subnets
  private_subnets         = var.private_subnets
  public_subnets          = var.public_subnets
  alb_ssl_certificate_arn = var.alb_ssl_certificate_arn
  route53_zone_name       = var.route53_zone_name
  tags                    = var.tags
}

output "dns_address" {
  value = module.awx.dns_address
}
