
output "awx_lb_target_group" {
  value = aws_lb_target_group.awx
}

output "awx_lb_listener" {
  value = aws_lb_listener.awx
}

output "dns_address" {
  value = aws_route53_record.url.fqdn
}
