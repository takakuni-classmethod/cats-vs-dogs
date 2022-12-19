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