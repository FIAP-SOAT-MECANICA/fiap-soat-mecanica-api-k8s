# API Gateway do cluster: controla e roteia as requisicoes ate os services das
# aplicacoes (ex: mecanica-api no repo -api, via um recurso Ingress la definido).
resource "helm_release" "traefik" {
  # 37.4.0 supports Kubernetes >= 1.22 in the official chart index.
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  version          = "37.4.0"
  namespace        = "traefik"
  create_namespace = true

  set {
    name  = "service.type"
    value = "NodePort"
  }

  set {
    name  = "ports.web.nodePort"
    value = var.traefik_node_port
  }

  depends_on = [aws_eks_node_group.this, aws_eks_addon.metrics_server]
}
