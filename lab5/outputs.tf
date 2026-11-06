output "vpc_id" {
  description = "ID of the VPC created by this configuration."
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "Public subnet IDs indexed by their stable input keys."
  value       = { for key, subnet in aws_subnet.public : key => subnet.id }
}

output "web_public_ip" {
  description = "Web instance public IP; LocalStack returns a simulated, unreachable address."
  value       = aws_instance.web.public_ip
}

output "web_url" {
  description = "Web URL once bootstrapping finishes on real AWS; not reachable in LocalStack."
  value       = "http://${aws_instance.web.public_ip}/"
}

output "artifact_bucket" {
  description = "Optional bucket name, or null when the bucket is disabled."
  value       = one(aws_s3_bucket.artifacts[*].bucket)
}

output "provider_target" {
  description = "Target selected by use_localstack; check this before applying any plan."
  value       = local.provider_target
}
