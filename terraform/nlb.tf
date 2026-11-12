# Borda publica da Fase 4. O padrao desligado evita expor servicos legados.
resource "aws_security_group" "traefik_nlb" {
  count       = var.enable_public_nlb ? 1 : 0
  name_prefix = "${var.project}-traefik-nlb-"
  description = "NLB publico para Traefik"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "nlb_http" {
  count             = var.enable_public_nlb ? 1 : 0
  security_group_id = aws_security_group.traefik_nlb[0].id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
  description       = "HTTP do API Gateway para o NLB"
}

resource "aws_vpc_security_group_egress_rule" "nlb_nodeport" {
  count                        = var.enable_public_nlb ? 1 : 0
  security_group_id            = aws_security_group.traefik_nlb[0].id
  ip_protocol                  = "tcp"
  from_port                    = var.traefik_node_port
  to_port                      = var.traefik_node_port
  referenced_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  description                  = "Traefik NodePort nos nodes EKS"
}

# Referenciar o SG do NLB aceita seu trafego mesmo com IP do cliente preservado.
resource "aws_vpc_security_group_ingress_rule" "nodes_from_nlb" {
  count                        = var.enable_public_nlb ? 1 : 0
  security_group_id            = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = var.traefik_node_port
  to_port                      = var.traefik_node_port
  referenced_security_group_id = aws_security_group.traefik_nlb[0].id
  description                  = "Traefik NodePort somente pelo NLB"
}

resource "aws_lb" "traefik" {
  count              = var.enable_public_nlb ? 1 : 0
  name               = "${var.project}-traefik"
  internal           = false
  load_balancer_type = "network"
  subnets            = local.subnet_ids
  security_groups    = [aws_security_group.traefik_nlb[0].id]
}

resource "aws_lb_target_group" "traefik" {
  count       = var.enable_public_nlb ? 1 : 0
  name_prefix = "tra-"
  port        = var.traefik_node_port
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = data.aws_vpc.default.id

  health_check {
    protocol = "TCP"
    port     = "traffic-port"
  }
}

resource "aws_lb_listener" "traefik_http" {
  count             = var.enable_public_nlb ? 1 : 0
  load_balancer_arn = aws_lb.traefik[0].arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.traefik[0].arn
  }
}

# O EKS gerencia o ASG. O nome atual troca com uma substituicao do node group.
resource "aws_autoscaling_attachment" "traefik" {
  count                  = var.enable_public_nlb ? 1 : 0
  autoscaling_group_name = aws_eks_node_group.this.resources[0].autoscaling_groups[0].name
  lb_target_group_arn    = aws_lb_target_group.traefik[0].arn

  depends_on = [helm_release.traefik, aws_vpc_security_group_ingress_rule.nodes_from_nlb]
}

resource "aws_ssm_parameter" "traefik_nlb_dns" {
  count = var.enable_public_nlb ? 1 : 0
  name  = coalesce(var.nlb_dns_ssm_parameter_name, "/${var.project}/k8s/nlb-dns")
  type  = "String"
  value = aws_lb.traefik[0].dns_name
}
