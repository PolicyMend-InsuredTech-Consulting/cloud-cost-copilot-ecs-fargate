# A minimal VPC, created only when no subnets are given: one public subnet, no NAT gateway. The task has
# no inbound ports (unless ingress_cidrs is set) and reaches AWS APIs through its public IP.
locals {
  create_vpc = length(var.subnet_ids) == 0
  vpc_id     = local.create_vpc ? aws_vpc.this[0].id : var.vpc_id
  subnet_ids = local.create_vpc ? [aws_subnet.public[0].id] : var.subnet_ids
}

data "aws_availability_zones" "available" {
  count = local.create_vpc ? 1 : 0
  state = "available"
}

#trivy:ignore:AVD-AWS-0178 flow logs are optional for a single outbound-only task; add them if your policy requires
resource "aws_vpc" "this" {
  count                = local.create_vpc ? 1 : 0
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "vpc-${var.name}" }
}

resource "aws_internet_gateway" "this" {
  count  = local.create_vpc ? 1 : 0
  vpc_id = aws_vpc.this[0].id
  tags   = { Name = "igw-${var.name}" }
}

resource "aws_subnet" "public" {
  count             = local.create_vpc ? 1 : 0
  vpc_id            = aws_vpc.this[0].id
  cidr_block        = var.vpc_cidr
  availability_zone = data.aws_availability_zones.available[0].names[0]
  tags              = { Name = "snet-${var.name}-public" }
}

resource "aws_route_table" "public" {
  count  = local.create_vpc ? 1 : 0
  vpc_id = aws_vpc.this[0].id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }
  tags = { Name = "rt-${var.name}-public" }
}

resource "aws_route_table_association" "public" {
  count          = local.create_vpc ? 1 : 0
  subnet_id      = aws_subnet.public[0].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_security_group" "task" {
  name        = "${var.name}-task"
  description = "Cloud Cost Copilot task: HTTPS out to AWS APIs; port 8080 in only from ingress_cidrs"
  vpc_id      = local.vpc_id
}

# Cost Explorer, Bedrock, License Manager, ECR, CloudWatch Logs and Session Manager are all HTTPS.
#trivy:ignore:AVD-AWS-0104 AWS API endpoints have no fixed address range
resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.task.id
  description       = "HTTPS to AWS APIs"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "ui" {
  for_each          = toset(var.ingress_cidrs)
  security_group_id = aws_security_group.task.id
  description       = "Copilot UI and API"
  cidr_ipv4         = each.key
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
}
