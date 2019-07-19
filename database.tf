# =============================================
#  RDS
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

  vpc_id  = var.vpc_id
  subnets = var.database_subnets

  allowed_security_groups       = [] #TODO
  allowed_security_groups_count = 0  #TODO
  instance_type                 = var.db_instance_type
  storage_encrypted             = true
  apply_immediately             = true

  db_parameter_group_name         = "default.aurora-postgresql10"
  db_cluster_parameter_group_name = "default.aurora-postgresql10"

  tags = local.common_tags
}
