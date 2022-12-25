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

resource "aws_iam_role_policy_attachment" "codebuild" {
  role = aws_iam_role.codebuild.name
  policy_arn = aws_iam_policy.codebuild.arn
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

  source {
    type = "CODEPIPELINE"
    buildspec = file("${path.module}/codesries_spec/buildspec.yaml")
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image_pull_credentials_type = "CODEBUILD"
    image = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.self.account_id
    }

    environment_variable {
      name = "CATS_ECR_REPOSITORY_NAME"
      value = aws_ecr_repository.cats.name
    }

    environment_variable {
      name = "DOGS_ECR_REPOSITORY_NAME"
      value = aws_ecr_repository.dogs.name
    }

    environment_variable {
      name = "WEB_ECR_REPOSITORY_NAME"
      value = aws_ecr_repository.web.name
    }
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
      group_name = aws_cloudwatch_log_group.codebuild.name
    }
  }

  cache {
    type = "LOCAL"
    modes = [
      "LOCAL_DOCKER_LAYER_CACHE",
      "LOCAL_SOURCE_CACHE"
    ]
  }
}

resource "aws_iam_role" "codepipeline" {
  name = "${local.prefix}-codepipeline-role"
  assume_role_policy = file("${path.module}/iam_policy_document/assume_codepipeline.json")

  tags = {
    Name = "${local.prefix}-codepipeline-role"
  }
}

resource "aws_iam_policy" "codepipeline" {
  name = "${local.prefix}-codepipeline-policy"
  policy = templatefile("${path.module}/iam_policy_document/iam_codepipeline.json", {
    task_execution_role_arn = aws_iam_role.task_exec.arn
  })

  tags = {
    Name = "${local.prefix}-codepipeline-policy"
  }
}

resource "aws_iam_role_policy_attachment" "codepipeline" {
  role = aws_iam_role.codepipeline.name
  policy_arn = aws_iam_policy.codepipeline.arn
}

resource "aws_s3_bucket" "artifact" {
  bucket = "${local.prefix}-artifact"
  tags = {
    Name = "${local.prefix}-artifact"
  }
  force_destroy = true # for testing

  # ignore SNYK-CC-TF-45
}

resource "aws_s3_bucket_ownership_controls" "artifact" {
  bucket = aws_s3_bucket.artifact.bucket

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifact" {
  bucket = aws_s3_bucket.artifact.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.key_id
    }
  }
}

resource "aws_s3_bucket_versioning" "artifact" {
  bucket = aws_s3_bucket.artifact.bucket

  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Disabled" # ignore SNYK-CC-TF-127
  }
}

resource "aws_s3_bucket_public_access_block" "artifact" {
  bucket = aws_s3_bucket.artifact.bucket

  restrict_public_buckets = true
  ignore_public_acls      = true
  block_public_acls       = true
  block_public_policy     = true
}

data "aws_codestarconnections_connection" "github" {
  name = "cats-vs-dogs"
}

resource "aws_codepipeline" "pipeline" {
  name = "${local.prefix}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    type = "S3"
    location = aws_s3_bucket.artifact.bucket

    encryption_key {
      id = aws_kms_key.s3.arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name = "Source"
      category = "Source"
      owner = "AWS"
      run_order = 1
      namespace = "SourceVariables"
      provider = "CodeStarSourceConnection"
      version = 1

      configuration = {
        ConnectionArn = data.aws_codestarconnections_connection.github.arn
        BranchName = "main"
        FullRepositoryId = var.repository_id
        OutputArtifactFormat = "CODE_ZIP"
      }

      output_artifacts = [ "SourceArtifact" ]
    }
  }

  stage {
    name = "Build"

    action {
      name = "Build"
      category = "Build"
      owner = "AWS"
      run_order = 1
      namespace = "BuildVariables"
      provider = "CodeBuild"
      input_artifacts = [ "SourceArtifact" ]
      version = 1

      configuration = {
        ProjectName = aws_codebuild_project.codebuild.name
      }

      output_artifacts = [ "BuildArtifact" ]
    }
  }

  stage {
    name = "Deploy"

    action {
      name = "Deploy_Cats"
      category = "Deploy"
      owner = "AWS"
      run_order = 1
      provider = "ECS"
      input_artifacts = [ "BuildArtifact" ]
      version = 1

      configuration = {
        ClusterName = aws_ecs_cluster.cluster.name
        ServiceName = aws_ecs_service.cats.name
        FileName = "imagedefinitions_cats.json"
      }
    }

    action {
      name = "Deploy_Dogs"
      category = "Deploy"
      owner = "AWS"
      run_order = 1
      provider = "ECS"
      input_artifacts = [ "BuildArtifact" ]
      version = 1

      configuration = {
        ClusterName = aws_ecs_cluster.cluster.name
        ServiceName = aws_ecs_service.dogs.name
        FileName = "imagedefinitions_dogs.json"
      }
    }

    action {
      name = "Deploy_Web"
      category = "Deploy"
      owner = "AWS"
      run_order = 1
      provider = "ECS"
      input_artifacts = [ "BuildArtifact" ]
      version = 1

      configuration = {
        ClusterName = aws_ecs_cluster.cluster.name
        ServiceName = aws_ecs_service.web.name
        FileName = "imagedefinitions_web.json"
      }
    }
  }
}