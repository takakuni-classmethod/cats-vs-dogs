######################################
# CloudWatch Logs Configuration
######################################
resource "aws_cloudwatch_log_group" "dogs" {
  name              = "/ecs/${local.prefix}/dogs"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cw_logs.arn

  tags = {
    Name = "/ecs/${local.prefix}/dogs"
  }
}

resource "aws_cloudwatch_log_group" "dogs_log_router" {
  name              = "/ecs/${local.prefix}/dogs-log-router"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cw_logs.arn

  tags = {
    Name = "/ecs/${local.prefix}/dogs-log-router"
  }
}

######################################
# Security Group Configuration
######################################
resource "aws_security_group" "dogs" {
  name        = "${local.prefix}-dogs-service-sg"
  description = "${local.prefix}-dogs-service-sg"
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${local.prefix}-dogs-service-sg"
  }
}

resource "aws_security_group_rule" "alb_dogs" {
  security_group_id = aws_security_group.alb.id
  type = "egress"
  protocol = "tcp"
  from_port = 80
  to_port = 80
  source_security_group_id = aws_security_group.dogs.id
  description = "dogs Container"
}

resource "aws_security_group_rule" "dogs_alb" {
  security_group_id = aws_security_group_rule.alb_dogs.source_security_group_id
  type = "ingress"
  protocol = aws_security_group_rule.alb_dogs.protocol
  from_port = aws_security_group_rule.alb_dogs.from_port
  to_port = aws_security_group_rule.alb_dogs.to_port
  source_security_group_id = aws_security_group_rule.alb_dogs.security_group_id
  description = "Application Load Balancer"
}

resource "aws_security_group_rule" "dogs_vpce" {
  security_group_id = aws_security_group.dogs.id
  type = "egress"
  protocol = "tcp"
  from_port = 443
  to_port = 443
  source_security_group_id = aws_security_group.vpce.id
  description = "VPC Endpoint"
}

resource "aws_security_group_rule" "dogs_vpce_s3" {
  security_group_id = aws_security_group.dogs.id
  type = "egress"
  protocol = "tcp"
  from_port = 443
  to_port = 443
  prefix_list_ids = [aws_vpc_endpoint.s3.prefix_list_id]
}

######################################
# Target Group Configuration
######################################
resource "aws_lb_target_group" "dogs" {
  name     = "${local.prefix}-dogs-service-tg"
  target_type = "ip"
  vpc_id   = aws_vpc.vpc.id
  protocol = aws_lb_listener.alb_80.protocol
  port     = aws_lb_listener.alb_80.port
  ip_address_type = "ipv4"


  health_check {
    enabled = true
    path = "/dogs/"
    healthy_threshold = 3
    unhealthy_threshold = 3
    interval = 30
    matcher = "200"
  }
}

resource "aws_lb_listener_rule" "dogs" {
  listener_arn = aws_lb_listener.alb_80.arn
  
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.dogs.arn
  }

  condition {
    path_pattern {
      values = [ "/dogs*" ]
    }
  }
}

######################################
# Task Definition Configuration
######################################
resource "aws_ecs_task_definition" "dogs" {
  family = "${local.prefix}-dogs-td"
  requires_compatibilities = [ "FARGATE" ]
  network_mode = "awsvpc"
  execution_role_arn = aws_iam_role.task_exec.arn

  memory = 512
  cpu = 256

  container_definitions = templatefile("${path.module}/task_definition/dogs.json", {
    region = data.aws_region.current.name

    dogs_image_url = aws_ecr_repository.dogs.repository_url
    log_group_name = aws_cloudwatch_log_group.dogs.name
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
resource "aws_ecs_service" "dogs" {
  name = "${local.prefix}-dogs-service"
  cluster = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.dogs.arn
  desired_count = 2
  launch_type = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.dogs.id]
    subnets = [aws_subnet.private_a.id, aws_subnet.private_c.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.dogs.arn
    container_name = "dogs"
    container_port = 80
  }

  tags = {
    Name = "${local.prefix}-dogs-service"
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}

######################################
# AutoScaling Configuration
######################################
resource "aws_appautoscaling_target" "dogs" {
  service_namespace = "ecs"
  resource_id = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.dogs.name}"
  max_capacity = 6
  min_capacity = 2
  scalable_dimension = "ecs:service:DesiredCount"
}

resource "aws_appautoscaling_policy" "dogs" {
  name = "${local.prefix}-dogs-target-policy"
  policy_type = "TargetTrackingScaling"

  service_namespace = aws_appautoscaling_target.dogs.service_namespace
  resource_id = aws_appautoscaling_target.dogs.resource_id
  scalable_dimension = aws_appautoscaling_target.dogs.scalable_dimension

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 45
  }
}