output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.microservices.id
}

output "ec2_public_ip" {
  description = "EC2 public IP"
  value       = aws_instance.microservices.public_ip
}

output "ec2_public_dns" {
  description = "EC2 public DNS"
  value       = aws_instance.microservices.public_dns
}

output "user_service_ecr_url" {
  description = "User service ECR repository"
  value       = aws_ecr_repository.user_service.repository_url
}

output "product_service_ecr_url" {
  description = "Product service ECR repository"
  value       = aws_ecr_repository.product_service.repository_url
}

output "order_service_ecr_url" {
  description = "Order service ECR repository"
  value       = aws_ecr_repository.order_service.repository_url
}
