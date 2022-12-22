######################################
# VPC Configuration
######################################
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.prefix}-vpc"
  }
}

######################################
# Public Subnet Configuration
######################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${local.prefix}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${local.prefix}-public-rtb"
  }
}

resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = "${data.aws_region.current.name}a"
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 4, 1)

  tags = {
    Name = "${local.prefix}-public-a-subnet"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "public_c" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = "${data.aws_region.current.name}c"
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 4, 2)

  tags = {
    Name = "${local.prefix}-public-c-subnet"
  }
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public.id
}

######################################
# Private Subnet Configuration
######################################
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${local.prefix}-private-rtb"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = "${data.aws_region.current.name}a"
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 4, 3)

  tags = {
    Name = "${local.prefix}-private-a-subnet"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = "${data.aws_region.current.name}c"
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 4, 4)

  tags = {
    Name = "${local.prefix}-private-c-subnet"
  }
}

resource "aws_route_table_association" "private_c" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private.id
}

######################################
# Isolate Subnet Configuration
######################################
resource "aws_route_table" "isolate" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${local.prefix}-isolate-rtb"
  }
}

resource "aws_subnet" "isolate_a" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = "${data.aws_region.current.name}a"
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 4, 5)

  tags = {
    Name = "${local.prefix}-isolate-a-subnet"
  }
}

resource "aws_route_table_association" "isolate_a" {
  subnet_id      = aws_subnet.isolate_a.id
  route_table_id = aws_route_table.isolate.id
}

resource "aws_subnet" "isolate_c" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = "${data.aws_region.current.name}c"
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 4, 6)

  tags = {
    Name = "${local.prefix}-isolate-c-subnet"
  }
}

resource "aws_route_table_association" "isolate_c" {
  subnet_id      = aws_subnet.isolate_c.id
  route_table_id = aws_route_table.isolate.id
}

######################################
# VPC Endpoint (Gateway) Configuration
######################################
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.vpc.id
  vpc_endpoint_type = "Gateway"
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  policy            = file("${path.module}/iam_policy_document/vpc_endpoint_default.json")

  tags = {
    Name = "${local.prefix}-s3-vpce"
  }
}

resource "aws_vpc_endpoint_route_table_association" "public" {
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
  route_table_id  = aws_route_table.public.id
}

resource "aws_vpc_endpoint_route_table_association" "private" {
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
  route_table_id  = aws_route_table.private.id
}

######################################
# VPC Endpoint (Interface) Configuration
######################################
resource "aws_security_group" "vpce" {
  name        = "${local.prefix}-vpce-sg"
  description = "${local.prefix}-vpce-sg"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "HTTPS from VPC"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }

  tags = {
    Name = "${local.prefix}-vpce-sg"
  }
}

######################################
# To Launch Fargate Task
######################################
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.vpc.id
  vpc_endpoint_type   = "Interface"
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  security_group_ids  = [aws_security_group.vpce.id]
  subnet_ids          = [aws_subnet.isolate_a.id, aws_subnet.isolate_c.id]
  policy              = file("${path.module}/iam_policy_document/vpc_endpoint_default.json")
  private_dns_enabled = true

  tags = {
    Name = "${local.prefix}-ecr-api-vpce"
  }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.vpc.id
  vpc_endpoint_type   = "Interface"
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  security_group_ids  = [aws_security_group.vpce.id]
  subnet_ids          = [aws_subnet.isolate_a.id, aws_subnet.isolate_c.id]
  policy              = file("${path.module}/iam_policy_document/vpc_endpoint_default.json")
  private_dns_enabled = true

  tags = {
    Name = "${local.prefix}-ecr-dkr-vpce"
  }
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.vpc.id
  vpc_endpoint_type   = "Interface"
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  security_group_ids  = [aws_security_group.vpce.id]
  subnet_ids          = [aws_subnet.isolate_a.id, aws_subnet.isolate_c.id]
  policy              = file("${path.module}/iam_policy_document/vpc_endpoint_default.json")
  private_dns_enabled = true

  tags = {
    Name = "${local.prefix}-logs-vpce"
  }
}

resource "aws_vpc_endpoint" "kms" {
  vpc_id              = aws_vpc.vpc.id
  vpc_endpoint_type   = "Interface"
  service_name        = "com.amazonaws.${data.aws_region.current.name}.kms"
  security_group_ids  = [aws_security_group.vpce.id]
  subnet_ids          = [aws_subnet.isolate_a.id, aws_subnet.isolate_c.id]
  policy              = file("${path.module}/iam_policy_document/vpc_endpoint_default.json")
  private_dns_enabled = true

  tags = {
    Name = "${local.prefix}-kms-vpce"
  }
}