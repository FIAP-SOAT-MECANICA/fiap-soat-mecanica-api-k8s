# API Gateway do cluster: controla e roteia as requisicoes ate os services das
# aplicacoes (ex: mecanica-api no repo -api, via um recurso Ingress la definido).
resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
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
