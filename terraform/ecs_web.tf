######################################
# CloudWatch Logs Configuration
######################################
resource "aws_cloudwatch_log_group" "web" {
  name              = "/ecs/${local.prefix}/web"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cw_logs.arn

  tags = {
    Name = "/ecs/${local.prefix}/web"
  }
}

resource "aws_cloudwatch_log_group" "web_log_router" {
  name              = "/ecs/${local.prefix}/web-log-router"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cw_logs.arn

  tags = {
    Name = "/ecs/${local.prefix}/web-log-router"
  }
}

######################################
# Security Group Configuration
######################################
resource "aws_security_group" "web" {
  name        = "${local.prefix}-web-service-sg"
  description = "${local.prefix}-web-service-sg"
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${local.prefix}-web-service-sg"
  }
}

resource "aws_security_group_rule" "alb_web" {
  security_group_id = aws_security_group.alb.id
  type = "egress"
  protocol = "tcp"
  from_port = 80
  to_port = 80
  source_security_group_id = aws_security_group.web.id
  description = "web Container"
}

resource "aws_security_group_rule" "web_alb" {
  security_group_id = aws_security_group_rule.alb_web.source_security_group_id
  type = "ingress"
  protocol = aws_security_group_rule.alb_web.protocol
  from_port = aws_security_group_rule.alb_web.from_port
  to_port = aws_security_group_rule.alb_web.to_port
  source_security_group_id = aws_security_group_rule.alb_web.security_group_id
  description = "Application Load Balancer"
}

resource "aws_security_group_rule" "web_vpce" {
  security_group_id = aws_security_group.web.id
  type = "egress"
  protocol = "tcp"
  from_port = 443
  to_port = 443
  source_security_group_id = aws_security_group.vpce.id
  description = "VPC Endpoint"
}

resource "aws_security_group_rule" "web_vpce_s3" {
  security_group_id = aws_security_group.web.id
  type = "egress"
  protocol = "tcp"
  from_port = 443
  to_port = 443
  prefix_list_ids = [aws_vpc_endpoint.s3.prefix_list_id]
}

######################################
# Target Group Configuration
######################################
resource "aws_lb_target_group" "web" {
  name     = "${local.prefix}-web-service-tg"
  target_type = "ip"
  vpc_id   = aws_vpc.vpc.id
  protocol = aws_lb_listener.alb_80.protocol
  port     = aws_lb_listener.alb_80.port
  ip_address_type = "ipv4"


  health_check {
    enabled = true
    path = "/"
    healthy_threshold = 3
    unhealthy_threshold = 3
    interval = 30
    matcher = "200"
  }
}

resource "aws_lb_listener_rule" "web" {
  listener_arn = aws_lb_listener.alb_80.arn
  
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  condition {
    path_pattern {
      values = [ "/" ]
    }
  }
}

data "aws_ecr_repository" "web" {
  name = "web"
}

######################################
# Task Definition Configuration
######################################
resource "aws_ecs_task_definition" "web" {
  family = "${local.prefix}-web-td"
  requires_compatibilities = [ "FARGATE" ]
  network_mode = "awsvpc"
  execution_role_arn = aws_iam_role.task_exec.arn

  memory = 512
  cpu = 256

  container_definitions = templatefile("${path.module}/task_definition/web.json", {
    region = data.aws_region.current.name

    web_image_url = data.aws_ecr_repository.web.repository_url
    log_group_name = aws_cloudwatch_log_group.web.name
    log_stream_prefix = "awslogs"
  })

  lifecycle {
    ignore_changes = [
      container_definitions
    ]
  }
}

######################################
# Task Definition Configuration
######################################
resource "aws_ecs_service" "web" {
  name = "${local.prefix}-web-service"
  cluster = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count = 2
  launch_type = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.web.id]
    subnets = [aws_subnet.private_a.id, aws_subnet.private_c.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.web.arn
    container_name = "web"
    container_port = 80
  }

  deployment_circuit_breaker {
    enable = true
    rollback = true
  }

  tags = {
    Name = "${local.prefix}-web-service"
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}

######################################
# AutoScaling Configuration
######################################
resource "aws_appautoscaling_target" "web" {
  service_namespace = "ecs"
  resource_id = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.web.name}"
  max_capacity = 6
  min_capacity = 2
  scalable_dimension = "ecs:service:DesiredCount"
}

resource "aws_appautoscaling_policy" "web" {
  name = "${local.prefix}-web-target-policy"
  policy_type = "TargetTrackingScaling"

  service_namespace = aws_appautoscaling_target.web.service_namespace
  resource_id = aws_appautoscaling_target.web.resource_id
  scalable_dimension = aws_appautoscaling_target.web.scalable_dimension

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 45
  }
}