######################################
# CloudWatch Logs Configuration
######################################
resource "aws_cloudwatch_log_group" "cats" {
  name              = "/ecs/${local.prefix}/cats"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cw_logs.arn

  tags = {
    Name = "/ecs/${local.prefix}/cats"
  }
}

resource "aws_cloudwatch_log_group" "cats_log_router" {
  name              = "/ecs/${local.prefix}/cats-log-router"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cw_logs.arn

  tags = {
    Name = "/ecs/${local.prefix}/cats-log-router"
  }
}

######################################
# Security Group Configuration
######################################
resource "aws_security_group" "cats" {
  name        = "${local.prefix}-cats-service-sg"
  description = "${local.prefix}-cats-service-sg"

  tags = {
    Name = "${local.prefix}-cats-service-sg"
  }
}


######################################
# Target Group Configuration
######################################
resource "aws_lb_target_group" "cats" {
  name     = "${local.prefix}-cats-service-tg"
  target_type = "ip"
  vpc_id   = aws_vpc.vpc.id
  protocol = aws_lb_listener.alb_80.protocol
  port     = aws_lb_listener.alb_80.port
  ip_address_type = "ipv4"


  health_check {
    enabled = true
    path = "/cats/"
    healthy_threshold = 3
    unhealthy_threshold = 3
    interval = 30
  }
}

