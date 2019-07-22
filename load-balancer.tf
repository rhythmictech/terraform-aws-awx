
# ALB

resource "aws_lb_target_group" "awx" {
  name_prefix = substr("${var.cluster_name}-tgtgrp", 0, 6)
  port        = 8052
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    interval            = 10
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "awx" {
  load_balancer_arn = module.ecs-cluster.alb-arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.alb_ssl_certificate_arn
  depends_on        = [aws_lb_target_group.awx]

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.awx.arn
  }
}

resource "aws_lb_listener" "https_redirect" {
  load_balancer_arn = module.ecs-cluster.alb-arn
  port              = 8052
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}