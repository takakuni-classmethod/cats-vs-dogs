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

resource "aws_cloudwatch_log_group" "bastion" {
  name              = "/ecs/${local.prefix}/bastion"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.cw_logs.arn

  tags = {
    Name = "/ecs/${local.prefix}/bastion/"
  }
}
