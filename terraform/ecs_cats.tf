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
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${local.prefix}-cats-service-sg"
  }
}

resource "aws_security_group_rule" "alb_cats" {
  security_group_id = aws_security_group.alb.id
  type = "egress"
  protocol = "tcp"
  from_port = 80
  to_port = 80
  source_security_group_id = aws_security_group.cats.id
  description = "Cats Container"
}

resource "aws_security_group_rule" "cats_alb" {
  security_group_id = aws_security_group_rule.alb_cats.source_security_group_id
  type = "ingress"
  protocol = aws_security_group_rule.alb_cats.protocol
  from_port = aws_security_group_rule.alb_cats.from_port
  to_port = aws_security_group_rule.alb_cats.to_port
  source_security_group_id = aws_security_group_rule.alb_cats.security_group_id
  description = "Application Load Balancer"
}

resource "aws_security_group_rule" "cats_vpce" {
  security_group_id = aws_security_group.cats.id
  type = "egress"
  protocol = "tcp"
  from_port = 443
  to_port = 443
  source_security_group_id = aws_security_group.vpce.id
  description = "VPC Endpoint"
}

resource "aws_security_group_rule" "cats_vpce_s3" {
  security_group_id = aws_security_group.cats.id
  type = "egress"
  protocol = "tcp"
  from_port = 443
  to_port = 443
  prefix_list_ids = [aws_vpc_endpoint.s3.prefix_list_id]
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
    matcher = "200"
  }
}

resource "aws_lb_listener_rule" "cats" {
  listener_arn = aws_lb_listener.alb_80.arn
  
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.cats.arn
  }

  condition {
    path_pattern {
      values = [ "/cats*" ]
    }
  }
}

data "aws_ecr_repository" "cats" {
  name = "cats"
}

######################################
# Task Definition Configuration
######################################
resource "aws_ecs_task_definition" "cats" {
  family = "${local.prefix}-cats-td"
  requires_compatibilities = [ "FARGATE" ]
  network_mode = "awsvpc"

  task_role_arn = aws_iam_role.task.arn
  execution_role_arn = aws_iam_role.task_exec.arn

  memory = 512
  cpu = 256

  container_definitions = templatefile("${path.module}/task_definition/cats.json", {
    region = data.aws_region.current.name

    cats_image_url = aws_ecr_repository.cats.repository_url
    cats_log_group_name = aws_cloudwatch_log_group.cats.name
    cats_log_stream_prefix = "fluentbit-"

    firelens_image_url = data.aws_ssm_parameter.firelens_image_url.value
    firelens_log_group_name = aws_cloudwatch_log_group.cats_log_router.name
    firelens_log_stream_prefix = "fluentbit"
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
resource "aws_ecs_service" "cats" {
  name = "${local.prefix}-cats-service"
  cluster = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.cats.arn
  desired_count = 2
  launch_type = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.cats.id]
    # subnets = [aws_subnet.public_a.id, aws_subnet.public_c.id]
    subnets = [aws_subnet.private_a.id, aws_subnet.private_c.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.cats.arn
    container_name = "cats"
    container_port = 80
  }

  tags = {
    Name = "${local.prefix}-cats-service"
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}

######################################
# AutoScaling Configuration
######################################
resource "aws_appautoscaling_target" "cats" {
  service_namespace = "ecs"
  resource_id = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.cats.name}"
  max_capacity = 6
  min_capacity = 2
  scalable_dimension = "ecs:service:DesiredCount"
}

resource "aws_appautoscaling_policy" "cats" {
  name = "${local.prefix}-cats-target-policy"
  policy_type = "TargetTrackingScaling"

  service_namespace = aws_appautoscaling_target.cats.service_namespace
  resource_id = aws_appautoscaling_target.cats.resource_id
  scalable_dimension = aws_appautoscaling_target.cats.scalable_dimension

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 45
  }
}