output "alb_dns_name" {
  value = module.ecs-cluster.alb-dns
}

output "awx_task_definition" {
  value = aws_ecs_task_definition.awx
}

output "awx_ecs_service" {
  value = aws_ecs_service.awx
}

output "awx_lb_target_group" {
  value = aws_lb_target_group.awx
}

output "awx_lb_listener" {
  value = aws_lb_listener.awx
}

# TODO: module 
# output "ecs_cluster" {
#   value = "value"
# }

output "ecs_private_key" {
  value = tls_private_key.ecs_root
}

output "ecs_iam_role" {
  value = aws_iam_role.ecs-service-role
}

# TODO: is a module
# output "rds_cluster" {
#   value = "value"
# }

# TODO: add security groups 

output "dns_address" {
  value = aws_route53_record.url.fqdn
}
