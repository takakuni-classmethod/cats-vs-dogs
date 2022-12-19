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