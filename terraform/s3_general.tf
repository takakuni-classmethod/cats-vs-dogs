######################################
# KMS (CMK) Configuration
######################################
resource "aws_kms_key" "s3" {
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy = templatefile("${path.module}/iam_policy_document/key_s3.json", {
    account_id = data.aws_caller_identity.self.account_id,
    region     = data.aws_region.current.name
    }
  )
}

resource "aws_kms_alias" "s3" {
  target_key_id = aws_kms_key.s3.key_id
  name          = "alias/${local.prefix}/s3"
}