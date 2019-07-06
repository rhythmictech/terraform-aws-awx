provider "aws" {
  region = "us-east-1"
}


module "awx" {
  source = "../"
  
  db_instance_type = var.db_instance_type
  vpc_id           = var.vpc_id
  cidr_block       = var.cidr_block
  database_subnets = var.database_subnets
  private_subnets  = var.private_subnets
  public_subnets   = var.public_subnets
}

output "alb_dns_name" {
  value = module.awx.alb_dns_name
}

output "ecs_private_key" {
  value = module.awx.ecs_private_key
}

