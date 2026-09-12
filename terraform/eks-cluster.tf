resource "aws_eks_cluster" "this" {
  name     = var.project
  role_arn = local.lab_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids = local.subnet_ids
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }
}
