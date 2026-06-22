resource "aws_ecr_repository" "app" {
  name                 = "${var.cluster_name}-2048"
  image_tag_mutability = "MUTABLE"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.tags, { Name = "${var.cluster_name}-2048" })
}