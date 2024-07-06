resource "aws_ecr_repository" "smarterise_ecr_repository" {
  name                 = "smarterise"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}