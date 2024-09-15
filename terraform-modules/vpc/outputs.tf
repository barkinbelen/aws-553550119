output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.vpc.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = aws_vpc.vpc.cidr_block
}

output "vpc_default_security_group_id" {
  description = "VPC default security group ID"
  value       = aws_vpc.vpc.default_security_group_id
}

output "public_subnets" {
  description = "Public subnets"
  value       = aws_subnet.vpc_public_subnets
}

output "private_subnets" {
  description = "Private subnets"
  value       = aws_subnet.vpc_private_subnets
}

output "public_route_table_ids" {
  description = "Public route table IDs"
  value       = aws_route_table.public_route_table.*.id
}

output "private_route_table_ids" {
  description = "Private route table IDs"
  value       = aws_route_table.private_route_tables.*.id
}
