######################################
# ECR Repository Configuration
######################################
resource "aws_kms_key" "ecr" {
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy = templatefile("${path.module}/iam_policy_document/key_ecr.json", {
    account_id = data.aws_caller_identity.self.account_id,
    region     = data.aws_region.current.name
    }
  )
}

resource "aws_kms_alias" "ecr" {
  target_key_id = aws_kms_key.ecr.key_id
  name          = "alias/${local.prefix}/ecr"
}

######################################
# ECR Repository Configuration Cats
######################################
resource "aws_ecr_repository" "cats" {
  name = "${local.prefix}-cats-repo"
  image_tag_mutability = "IMMUTABLE"
  force_delete = true

  encryption_configuration {
    encryption_type = "KMS"
    kms_key = aws_kms_key.ecr.arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${local.prefix}-cats-repo"
  }
}

resource "aws_ecr_lifecycle_policy" "cats" {
  repository = aws_ecr_repository.cats.id
  policy = file("${path.module}/ecr_lifecycle/lifecycle.json")
}

######################################
# ECR Repository Configuration Dogs
######################################
resource "aws_ecr_repository" "dogs" {
  name = "${local.prefix}-dogs-repo"
  image_tag_mutability = "IMMUTABLE"
  force_delete = true

  encryption_configuration {
    encryption_type = "KMS"
    kms_key = aws_kms_key.ecr.arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${local.prefix}-dogs-repo"
  }
}

resource "aws_ecr_lifecycle_policy" "dogs" {
  repository = aws_ecr_repository.dogs.id
  policy = file("${path.module}/ecr_lifecycle/lifecycle.json")
}

######################################
# ECR Repository Configuration Web
######################################
resource "aws_ecr_repository" "web" {
  name = "${local.prefix}-web-repo"
  image_tag_mutability = "IMMUTABLE"
  force_delete = true

  encryption_configuration {
    encryption_type = "KMS"
    kms_key = aws_kms_key.ecr.arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${local.prefix}-web-repo"
  }
}

resource "aws_ecr_lifecycle_policy" "web" {
  repository = aws_ecr_repository.web.id
  policy = file("${path.module}/ecr_lifecycle/lifecycle.json")
}