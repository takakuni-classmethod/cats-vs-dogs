######################################
# Security Group Configuration (ALB)
######################################
data "http" "ifconfig" {
  url = "http://ipv4.icanhazip.com/"
}

resource "aws_security_group" "alb" {
  name        = "${local.prefix}-alb-sg"
  description = "${local.prefix}-alb-sg"
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${local.prefix}-alb-sg"
  }
}

resource "aws_security_group_rule" "alb_ingress_myip" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  protocol          = "tcp"
  to_port           = 80
  from_port         = 80
  cidr_blocks       = ["${chomp(data.http.ifconfig.response_body)}/32"]
  description       = "Connection from My IP."
}

######################################
# Access Log Configuration (ALB)
######################################
data "aws_elb_service_account" "this" {}

resource "aws_s3_bucket" "alb" {
  bucket = "${local.prefix}-alb-log"
  tags = {
    Name = "${local.prefix}-alb-log"
  }
  force_destroy = true # for testing

  # ignore SNYK-CC-TF-45
}

resource "aws_s3_bucket_ownership_controls" "access_logs_alb" {
  bucket = aws_s3_bucket.alb.bucket

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "access_logs_alb" {
  bucket = aws_s3_bucket.alb.bucket
  policy = templatefile("${path.module}/iam_policy_document/bucket_alb.json",{
    elb_account_id = data.aws_elb_service_account.this.id
    alb_bucket_arn = aws_s3_bucket.alb.arn
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs_alb" {
  bucket = aws_s3_bucket.alb.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "access_logs_alb" {
  bucket = aws_s3_bucket.alb.bucket

  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Disabled" # ignore SNYK-CC-TF-127
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs_alb" {
  bucket = aws_s3_bucket.alb.bucket

  restrict_public_buckets = true
  ignore_public_acls      = true
  block_public_acls       = true
  block_public_policy     = true
}

######################################
# Load Balancer Configuration (ALB)
######################################
resource "aws_lb" "alb" {
  name                       = "${local.prefix}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = [aws_subnet.public_a.id, aws_subnet.public_c.id]
  drop_invalid_header_fields = true

  enable_deletion_protection = false # for testing

  access_logs {
    bucket  = aws_s3_bucket.alb.bucket
    enabled = true
  }
}

resource "aws_lb_listener" "alb_80" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/html"
      status_code  = "403"
      message_body = file("${path.module}/fixed_responce/403.html")
    }
  }
}