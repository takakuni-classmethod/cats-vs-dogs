######################################
# CodeBuild Configuration
######################################
resource "aws_iam_role" "codebuild" {
  name = "${local.prefix}-codebuild-role"
  assume_role_policy = file("${path.module}/iam_policy_document/assume_codebuild.json")

  tags = {
    Name = "${local.prefix}-codebuild-role"
  }
}

resource "aws_iam_policy" "codebuild" {
  name = "${local.prefix}-codebuild-policy"
  policy = file("${path.module}/iam_policy_document/iam_codebuild.json")

  tags = {
    Name = "${local.prefix}-codebuild-policy"
  }
}

resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/codebuild/${local.prefix}"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cw_logs.arn

  tags = {
    Name = "/codebuild/${local.prefix}"
  }
}

resource "aws_codebuild_project" "codebuild" {
  name = "${local.prefix}-project"
  description = "${local.prefix}-project"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image_pull_credentials_type = "CODEBUILD"
    image = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type = "LINUX_CONTAINER"
    privileged_mode = true
  }
}