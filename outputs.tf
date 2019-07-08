output "alb_dns_name" {
  value = module.ecs-cluster.alb-dns
}

output "ecs_private_key" {
  value = tls_private_key.ecs_root.private_key_pem
}
