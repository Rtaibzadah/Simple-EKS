resource "aws_route53_zone" "eks_subdomain" {
  name          = "eks.digitalcncloud.org"
  force_destroy = true
  tags          = merge(local.tags, { Name = "eks.digitalcncloud.org" })
}