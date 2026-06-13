output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "A map of the subnet names to their IDs"
  value       = { for k, v in aws_subnet.multi_tier : k => v.id }
}