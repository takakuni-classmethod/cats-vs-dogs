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