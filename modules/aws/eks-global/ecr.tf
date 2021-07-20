resource "aws_ecr_repository" "ecr" {
  name                 = "acrr${var.environment}${var.location_short}${var.name}${var.unique_suffix}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
