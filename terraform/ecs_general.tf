######################################
# CloudWatch Logs Configuration
######################################
resource "aws_kms_key" "cw_logs" {
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy = templatefile("${path.module}/iam_policy_document/key_cwl.json", {
    account_id = data.aws_caller_identity.self.account_id,
    region     = data.aws_region.current.name
    }
  )
}

resource "aws_kms_alias" "cw_logs" {
  target_key_id = aws_kms_key.cw_logs.key_id
  name          = "alias/${local.prefix}/cw_logs"
}

resource "aws_cloudwatch_log_group" "ecs_exec" {
  name              = "/ecs/${local.prefix}/ecs-exec"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cw_logs.arn

  tags = {
    Name = "/ecs/${local.prefix}/ecs-exec"
  }
}

######################################
# ECS Cluster Configuration
######################################
resource "aws_ecs_cluster" "cluster" {
  name = "${local.prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      kms_key_id = aws_kms_key.cw_logs.key_id
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs_exec.name
      }
    }
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