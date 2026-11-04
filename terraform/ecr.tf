resource "aws_ecr_repository" "user_service" {
  name                 = "microservices-devops/user-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = var.project_name
    Service = "user-service"
  }
}

resource "aws_ecr_repository" "product_service" {
  name                 = "microservices-devops/product-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = var.project_name
    Service = "product-service"
  }
}

resource "aws_ecr_repository" "order_service" {
  name                 = "microservices-devops/order-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = var.project_name
    Service = "order-service"
  }
}
