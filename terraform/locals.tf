locals {
  account_id   = data.aws_caller_identity.current.account_id
  lab_role_arn = "arn:aws:iam::${local.account_id}:role/${var.lab_role_name}"

  subnet_ids = [
    for subnet in data.aws_subnet.default : subnet.id
    if !contains(var.excluded_availability_zones, subnet.availability_zone)
  ]

  common_tags = {
    Project    = var.project
    ManagedBy  = "terraform"
    Repository = "fiap-soat-mecanica-api-k8s"
  }
}
