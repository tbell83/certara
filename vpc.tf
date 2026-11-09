resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}

data "aws_availability_zones" "azs" {
  state = "available"
}

locals {
  azs = toset(slice(data.aws_availability_zones.azs.names, 0, 2))
}

resource "aws_subnet" "private" {
  for_each          = local.azs
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.10.${index(tolist(local.azs), each.key) * 10}.0/24"
  availability_zone = each.key

  tags = {
    Name = "private-${each.key}"
    Type = "private"
  }
}

resource "aws_subnet" "public" {
  for_each          = local.azs
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.20.${index(tolist(local.azs), each.key) * 10}.0/24"
  availability_zone = each.key

  tags = {
    Name = "public-${each.key}"
    Type = "public"
  }
}

data "aws_vpc_endpoint_service" "s3" {
  service      = "s3"
  service_type = "Gateway"
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = data.aws_vpc_endpoint_service.s3.service_name
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private.id,
    aws_route_table.public.id,
  ]
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_nat_gateway" "nat" {
  availability_mode = "regional"
  vpc_id            = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "private_nat" {
  for_each       = aws_subnet.private
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private.id
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"
}

output "vpc_id" {
  value = aws_vpc.main.id
}
