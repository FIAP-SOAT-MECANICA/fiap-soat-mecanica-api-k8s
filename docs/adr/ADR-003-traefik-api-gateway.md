# ADR-003: Traefik como API Gateway dentro do cluster

- **Status:** Aceito
- **Data:** 2026-09-15
- **Repositório:** fiap-soat-mecanica-api-k8s
- **Implementação:** `terraform/traefik.tf` (PR #3)

## Contexto

O Tech Challenge exige um **API Gateway** "para controle e roteamento" das
requisições, com as rotas sensíveis protegidas por autenticação. O enunciado
lista como exemplos AWS API Gateway, Kong e Traefik, e deixa a escolha livre.

Restrições que pesaram na decisão:

- O AWS Academy Learner Lab não permite criar IAM Roles. O AWS API Gateway
  integrado ao EKS exige VPC Link e, para o AWS Load Balancer Controller,
  uma role via IRSA — ambos inviáveis ou frágeis nesse ambiente.
- O gateway precisa ser provisionado por Terraform junto com o cluster, para
  que o repositório da aplicação (#4) só precise declarar **para onde** rotear.
- Crédito limitado: cada load balancer da AWS custa ~US$ 0,02/h + tráfego.

## Decisão

Instalar o **Traefik** no cluster via Helm (`helm_release.traefik`, chart
oficial `traefik/traefik`), no namespace `traefik`, como o API Gateway da
solução.

- O `Service` do Traefik é do tipo **`NodePort`**, entrypoint HTTP na porta
  `30090` (variável `traefik_node_port`, validada entre 30000 e 32767). Não
  é criado load balancer da AWS.
- O provider `helm` é configurado com `aws eks get-token` (token de curta
  duração), apontando para o cluster criado no mesmo `apply`.
- A instalação depende do node group e do addon `metrics-server`, para que o
  Traefik só seja agendado quando houver nodes prontos.
- **Divisão de responsabilidade:** este repositório instala o gateway; o
  repositório da aplicação (#4) declara um recurso `Ingress` apontando para o
  `Service` `traefik` (output `traefik_namespace`), com as regras de rota da
  API. O mesmo vale para middlewares de autenticação, se forem usados.

## Consequências

**Positivas**
- Gateway 100% em Terraform, sem IAM adicional — funciona em qualquer conta do
  Learner Lab.
- Roteamento declarativo via `Ingress`, que é o objeto padrão do Kubernetes;
  a aplicação não precisa conhecer o Traefik.
- Dashboard e métricas nativas do Traefik podem alimentar a observabilidade
  (latência por rota).
- Custo zero além dos nodes.

**Negativas / riscos**
- `NodePort` expõe o gateway em `http://<IP público do node>:30090`. O IP
  muda quando o node é substituído e o security group dos nodes precisa
  liberar a porta. Para um endereço estável seria necessário um NLB
  (`Service` tipo `LoadBalancer`) — decisão que pode ser revista se o
  Lambda/API Gateway (repo #1) precisar de um endpoint fixo.
- Somente HTTP no entrypoint `web`; TLS não está configurado.
- O chart não está com versão fixada (`version` ausente no `helm_release`),
  o que pode trazer mudanças inesperadas em um `apply` futuro. Recomenda-se
  fixar a versão.

## Alternativas consideradas

| Alternativa | Motivo da rejeição |
| --- | --- |
| AWS API Gateway + VPC Link | Exige NLB e roles IAM; complexidade alta no Learner Lab |
| AWS Load Balancer Controller (ALB Ingress) | Precisa de IRSA (IAM Role) — não permitido |
| Kong | Mais pesado (banco próprio ou modo DB-less com mais configuração); sem ganho para o escopo |
| NGINX Ingress | Equivalente ao Traefik, mas o Traefik tem dashboard e middlewares de autenticação prontos, úteis para o requisito de rotas protegidas |
