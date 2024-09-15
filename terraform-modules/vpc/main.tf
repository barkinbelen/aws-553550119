# Create VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block

  enable_dns_support = true

  enable_dns_hostnames = true

  tags = merge(
    { Name = "${title(var.project_name)}-VPC-${title(var.env)}" },
    var.extra_tags
  )
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = merge(
    { Name = "${title(var.project_name)}-VPC-${title(var.env)}-IGW" },
    var.extra_tags
  )
}

# Fetch availability zones in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Get base CIDR block value for subnets
locals {
  base_cidr = regex("^([0-9]+\\.[0-9]+)", var.cidr_block)[0]
}

# Create public subnets
resource "aws_subnet" "vpc_public_subnets" {
  count                   = var.subnet_count
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "${local.base_cidr}.${element(var.public_subnet_suffixes, count.index)}"
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true

  tags = merge(
    { Name = "${var.project_name}-${var.env}-Public-Subnet-${count.index + 1}" },
    var.extra_tags
  )
}

# Create private subnets
resource "aws_subnet" "vpc_private_subnets" {
  count             = var.subnet_count
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "${local.base_cidr}.${element(var.private_subnet_suffixes, count.index)}"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = merge(
    { Name = "${var.project_name}-${var.env}-Private-Subnet-${count.index + 1}" },
    var.extra_tags,
  )
}

# Create NAT gateway EIPs
resource "aws_eip" "nat_eips" {
  count = var.subnet_count
  depends_on = [
    aws_internet_gateway.igw
  ]
  tags = merge(
    { Name = "${title(var.project_name)} NAT Gateway - ${count.index + 1}" },
    var.extra_tags
  )
}

# Create NAT gateways
resource "aws_nat_gateway" "nat_gateways" {
  count         = var.subnet_count
  allocation_id = aws_eip.nat_eips[count.index].id
  subnet_id     = aws_subnet.vpc_public_subnets[count.index].id

  tags = merge(
    { Name = "${title(var.project_name)} NAT Gateway - ${count.index + 1}" },
    var.extra_tags
  )
}

# Create public route table, route and table association
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(
    { Name = "${title(var.project_name)} Public Route Table" },
    var.extra_tags
  )
}

resource "aws_route" "public_route_table_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_association" {
  count     = var.subnet_count
  subnet_id = aws_subnet.vpc_public_subnets[count.index].id

  route_table_id = aws_route_table.public_route_table.id

}

# Create privatte route tables, routes and table associations
resource "aws_route_table" "private_route_tables" {
  count  = var.subnet_count
  vpc_id = aws_vpc.vpc.id

  tags = merge(
    { Name = "${title(var.project_name)} Private Route Table ${count.index + 1}" },
    var.extra_tags
  )
}

resource "aws_route" "private_route_table_routes" {
  count                  = var.subnet_count
  route_table_id         = aws_route_table.private_route_tables[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateways[count.index].id
}

resource "aws_route_table_association" "private_association" {
  count     = var.subnet_count
  subnet_id = aws_subnet.vpc_private_subnets[count.index].id

  route_table_id = aws_route_table.private_route_tables[count.index].id
}

