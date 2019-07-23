
# =============================================
# Route 53 | DNS
# =============================================

data "aws_route53_zone" "zone" {
  name = var.route53_zone_name
}

resource "aws_route53_record" "url" {
  zone_id = data.aws_route53_zone.zone.zone_id
  type    = "A"
  name    = "${var.cluster_name}.${data.aws_route53_zone.zone.name}"

  alias {
    name                   = module.ecs-cluster.alb-dns
    zone_id                = module.ecs-cluster.alb-zone
    evaluate_target_health = false
  }
}

# =============================================
#  INGRESS-EGRESSS
# =============================================

resource "aws_security_group_rule" "ecs_alb_ingress_80" {
  security_group_id = module.ecs-cluster.alb-sg-id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ecs_alb_ingress_443" {
  security_group_id = module.ecs-cluster.alb-sg-id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ecs_alb_egress" {
  security_group_id = module.ecs-cluster.alb-sg-id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [var.cidr_block]
}

resource "aws_security_group_rule" "ecs_ec2_ingress_from_alb" {
  security_group_id        = aws_security_group.ecs_service_egress.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = module.ecs-cluster.alb-sg-id
}

resource "aws_security_group" "ecs_service_egress" {
  name_prefix = "awx_default"
  description = "Default Security Group for AWX ECS Services"
  vpc_id      = var.vpc_id

  tags = local.common_tags
}

resource "aws_security_group_rule" "ecs_egress" {
  security_group_id = aws_security_group.ecs_service_egress.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_all" {
  security_group_id = aws_security_group.ecs_service_egress.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# resource "aws_security_group_rule" "rds_ingress" {
#   type                     = "ingress"
#   description              = "Allow ECS RDS Communication"
#   from_port                = 5432
#   to_port                  = 5432
#   protocol                 = "tcp"
#   security_group_id        = module.database.this_security_group_id
#   source_security_group_id = aws_security_group.ecs_service_egress.id
# }
