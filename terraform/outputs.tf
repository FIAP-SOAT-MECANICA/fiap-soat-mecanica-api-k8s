output "account_id" {
  value       = local.account_id
  description = "Conta AWS onde a infraestrutura foi aplicada."
}

output "region" {
  value       = var.aws_region
  description = "Regiao do cluster."
}

output "cluster_name" {
  value       = aws_eks_cluster.this.name
  description = "Nome do cluster EKS."
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.this.endpoint
  description = "Endpoint da API do Kubernetes."
}

output "cluster_certificate_authority" {
  value       = aws_eks_cluster.this.certificate_authority[0].data
  description = "CA do cluster em base64."
  sensitive   = true
}

output "cluster_security_group_id" {
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  description = "Security group aplicado aos nodes. O RDS deve liberar 5432 para este SG."
}

output "vpc_id" {
  value       = data.aws_vpc.default.id
  description = "VPC onde o cluster esta. O RDS deve ser criado nela."
}

output "subnet_ids" {
  value       = local.subnet_ids
  description = "Subnets usadas pelo cluster e pelos nodes."
}

output "lab_role_arn" {
  value       = local.lab_role_arn
  description = "Role usada por control plane e nodes."
}

output "kubeconfig_command" {
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.this.name} --region ${var.aws_region}"
  description = "Comando para configurar o kubectl local ou na pipeline da aplicacao."
}

output "traefik_namespace" {
  value       = helm_release.traefik.namespace
  description = "Namespace do gateway Traefik. O repo #4 (API) aplica um Ingress apontando para o Service 'traefik' nesse namespace."
}

output "opentelemetry_operator_namespace" {
  value       = helm_release.opentelemetry_operator.namespace
  description = "Namespace do OpenTelemetry Operator. O repo #4 (API) aplica o OpenTelemetryCollector e a Instrumentation no namespace da propria aplicacao; o Operator so precisa estar Available antes disso."
}
