######################################
# ECS Cluster Configuration
######################################
resource "aws_ecs_cluster" "cluster" {
  name = "${local.prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${local.prefix}-cluster"
  }
}

resource "aws_ecs_cluster_capacity_providers" "cluster" {
  cluster_name       = aws_ecs_cluster.cluster.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
  }
}

######################################
# ECS Task Roles Configuration
######################################
resource "aws_iam_role" "task_exec" {
  name               = "${local.prefix}-task-exec-role"
  assume_role_policy = file("${path.module}/iam_policy_document/assume_ecs_task.json")

  tags = {
    Name = "${local.prefix}-task-exec-role"
  }
}

resource "aws_iam_role_policy_attachment" "task_exec_managed" {
  role       = aws_iam_role.task_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}