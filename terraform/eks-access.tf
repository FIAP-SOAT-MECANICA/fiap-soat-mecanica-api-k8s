# A sessao do Learner Lab (console, CLI e GitHub Actions) assume a role voclabs.
# Sem este access entry, kubectl responde Unauthorized.
resource "aws_eks_access_entry" "lab_session" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = local.lab_session_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "lab_session_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.lab_session.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
