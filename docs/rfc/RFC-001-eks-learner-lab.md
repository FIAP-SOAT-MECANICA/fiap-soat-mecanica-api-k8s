# RFC-001: Provisionamento do cluster Kubernetes com EKS no AWS Academy Learner Lab

- **Status:** Aprovado
- **Data:** 2026-09-14
- **Autora:** Karen Barcelos
- **Repositório:** fiap-soat-mecanica-api-k8s

## Resumo

Propõe-se provisionar o cluster Kubernetes da Mecânica do Braia com **Amazon
EKS**, via Terraform, dentro das restrições do **AWS Academy Learner Lab**,
usando a **VPC default** da conta, a role pré-existente **`LabRole`** e um
**managed node group EC2**. Esta RFC registra as alternativas avaliadas, as
restrições que moldaram a solução e o custo estimado.

## Motivação

A Fase 3 exige cluster Kubernetes com escalabilidade, provisionado por
Terraform, com pipeline de CI/CD e infraestrutura em nuvem. O grupo já havia
escolhido AWS como provedor. Restava definir **como** criar o cluster de forma
reproduzível em quatro contas diferentes (uma por integrante) e, no final, em
uma única conta de entrega — tudo com crédito limitado e sem permissão para
criar identidades IAM.

## Restrições do Learner Lab que moldaram a proposta

| Restrição | Impacto |
| --- | --- |
| Não é possível criar IAM Roles, políticas ou OIDC providers | Sem roles dedicadas para cluster/nodes; sem IRSA; sem OIDC GitHub→AWS |
| Existem apenas as roles `LabRole` (ampla) e `voclabs` (sessão) | Tudo roda com `LabRole`; a sessão que executa o Terraform é `voclabs` |
| Credenciais temporárias (~4h): access key + secret + session token | Pipeline usa secrets rotativos; nada de credencial estática |
| Crédito de ~US$ 50 por conta | Arquitetura mínima; `destroy` diário |
| Recursos persistem após a sessão | Workflow de `destroy` manual |
| Região restrita (`us-east-1` / `us-west-2`) | Tudo em `us-east-1` |
| EKS não aceita control plane na AZ `us-east-1e` | Subnet dessa AZ é filtrada |
| Quatro contas durante o desenvolvimento, uma na entrega | Código sem account ID, ARN ou bucket fixos |

## Proposta

### 1. EKS com managed node group EC2

- Cluster `mecanica`, versão padrão do EKS (1.36 na data desta RFC).
- `role_arn` e `node_role_arn` apontam para `arn:aws:iam::<conta>:role/LabRole`,
  com `<conta>` resolvido em tempo de execução por `aws_caller_identity`.
- Node group: `t3.medium`, disco 50 GiB, min 1 / desired 2 / max 3.
- Addon gerenciado `metrics-server` para o HPA (ver ADR-001).
- `access_config`: `API_AND_CONFIG_MAP` com
  `bootstrap_cluster_creator_admin_permissions = true`. Como toda sessão do
  Learner Lab assume `voclabs`, o criador do cluster já é a role que console,
  CLI e pipeline usam — não é necessário access entry adicional (um entry
  explícito foi testado e falhou com `409 ResourceInUseException`).

### 2. VPC default em vez de VPC dedicada

A VPC default (`172.31.0.0/16`) existe em toda conta, com uma subnet pública
por AZ e Internet Gateway. Usá-la elimina: criação de VPC, subnets, route
tables, NAT Gateway (~US$ 0,045/h + tráfego) e as tags exigidas pelo EKS.
O repositório do banco (RDS) usa a mesma VPC, lida por `data source`, o que
simplifica o contrato entre repositórios. O trade-off é que os nodes ficam em
subnets públicas — aceitável para o escopo acadêmico, pois o acesso à API
passa pelo API Gateway e o RDS não é publicamente acessível.

### 3. Terraform com backend S3 parametrizado por conta

- Bucket `mecanica-tfstate-<account-id>`, criado por script (`bootstrap/`)
  fora do Terraform — o bucket precisa existir antes do primeiro `init`.
- Lock nativo do S3 (`use_lockfile = true`, Terraform ≥ 1.10), dispensando
  DynamoDB.
- `backend.hcl` local (ignorado pelo Git) em desenvolvimento; na pipeline, o
  nome do bucket é montado a partir de `aws sts get-caller-identity`.
- Migração para a conta final: rodar o bootstrap lá, apontar os secrets da
  pipeline para essa conta, `apply`. Nenhuma alteração de código.

### 4. Pipeline (GitHub Actions)

- PR → `fmt`, `validate`, `plan` comentado.
- Merge em `main` → `apply`.
- Manual → `destroy` com confirmação.
- Secrets: os três valores da sessão do Learner Lab. Sem OIDC (não permitido).

### 5. Componentes de plataforma via Helm

Além do cluster, o mesmo `apply` instala, com o provider `helm` autenticado
por `aws eks get-token`:

- **Traefik** como API Gateway do cluster (`Service` `NodePort` 30090) — ver
  [ADR-003](../adr/ADR-003-traefik-api-gateway.md).
- **OpenTelemetry Operator** (v0.114.0) como base de observabilidade — ver
  [ADR-004](../adr/ADR-004-opentelemetry-operator.md).

A aplicação (repo #4) consome os dois por objetos Kubernetes (`Ingress`,
`OpenTelemetryCollector`, `Instrumentation`) no próprio namespace.

### 6. Regra de egress no security group do cluster

O security group que o EKS cria para o cluster nem sempre vem com a regra de
saída `0.0.0.0/0`. Sem ela os nodes não alcançam os endpoints de EC2/EKS/ECR
durante o bootstrap e o node group falha com *"failed to join the cluster"*.
O repositório adiciona explicitamente
`aws_vpc_security_group_egress_rule.cluster_all_egress` e faz o node group
depender dela.

## Alternativas avaliadas

### Cluster Kubernetes

| Opção | Prós | Contras | Decisão |
| --- | --- | --- | --- |
| **EKS (managed)** | Control plane gerenciado, addons oficiais, padrão do mercado, exemplo do professor usa | Custo fixo de ~US$ 0,10/h | **Escolhido** |
| kubeadm em EC2 | Sem custo de control plane | Manutenção manual, sem addons gerenciados, difícil de reproduzir em 4 contas | Rejeitado |
| k3s / Kind em EC2 | Barato, leve | Não é "cluster gerenciado"; foge do espírito do requisito | Rejeitado |
| ECS / Fargate | Mais barato | Não é Kubernetes — requisito explícito do enunciado | Rejeitado |

### Nodes

| Opção | Decisão | Motivo |
| --- | --- | --- |
| **Managed node group EC2** | **Escolhido** | Suporta DaemonSets, `kubectl top`, HPA direto; sem IAM extra |
| Fargate | Rejeitado | Pod execution role (IAM), sem DaemonSets, cold start da JVM |
| Self-managed EC2 | Rejeitado | Mais trabalho sem ganho |

### Rede

| Opção | Decisão | Motivo |
| --- | --- | --- |
| **VPC default** | **Escolhido** | Zero custo de NAT, existe em toda conta, padrão do professor |
| VPC dedicada com subnets privadas + NAT | Rejeitado | ~US$ 1/dia só de NAT; mais recursos para manter; sem benefício visível na avaliação |

### Autenticação no cluster

| Opção | Decisão | Motivo |
| --- | --- | --- |
| **Bootstrap admin para o criador (`voclabs`)** | **Escolhido** | Toda sessão do lab é `voclabs`; testado e funcional |
| Access entry explícito para `voclabs` | Rejeitado | Conflita com o bootstrap (409); manter os dois falha |
| aws-auth ConfigMap | Rejeitado | Modo legado; access entries são o padrão atual |

### Backend de state

| Opção | Decisão | Motivo |
| --- | --- | --- |
| **S3 + lockfile nativo** | **Escolhido** | Um recurso só; funciona em qualquer conta |
| S3 + DynamoDB | Rejeitado | Recurso extra por conta sem ganho (lockfile nativo já resolve) |
| Terraform Cloud | Rejeitado | Dependência externa; credenciais rotativas complicam |
| State local | Rejeitado | Pipeline não teria acesso; outros repos não leriam outputs |

## Custo estimado (us-east-1, on-demand)

| Item | Valor/h | Valor/dia (24h) |
| --- | --- | --- |
| EKS control plane | US$ 0,10 | US$ 2,40 |
| 2 × t3.medium | US$ 0,083 | US$ 2,00 |
| 2 × EBS 50 GiB gp3 | ~US$ 0,011 | ~US$ 0,27 |
| **Total ligado** | **~US$ 0,19** | **~US$ 4,70** |

Com US$ 50 de crédito: ~10 dias ligado ininterruptamente, ou ~40 sessões de
trabalho de 6 horas com `destroy` ao final. Daí a exigência do `destroy` diário
e o ADR-002 (ambiente único).

## Validação realizada

Em 2026-09-13, na conta `999829182752` (Learner Lab da autora):

- `terraform apply`: cluster criado em 9m22s, node group em 1m59s, addon em 36s.
- `aws eks update-kubeconfig` + `kubectl get nodes`: 2 nodes `Ready`,
  Kubernetes v1.36.3.
- `kubectl top nodes`: métricas disponíveis (metrics-server ativo).
- `terraform destroy`: 3 recursos removidos em ~10 min.
- Pipeline: job `validate` verde no PR; `apply` automático dispara no merge
  (falhou apenas por ausência de secrets, conforme esperado).

Em 2026-09-15, com os secrets cadastrados: `Terraform Apply` executado pelo
GitHub Actions com sucesso de ponta a ponta (credenciais, `init` no bucket da
conta, `plan`, `apply`, outputs), sem intervenção local.

## Riscos e mitigações

| Risco | Mitigação |
| --- | --- |
| Credenciais expiram no meio de um `apply` de 15 min | Renovar secrets imediatamente antes de disparar; `apply` é idempotente, basta reexecutar |
| Cluster esquecido consumindo crédito | Workflow `Terraform Destroy` acessível pelo GitHub; instrução no README |
| Nodes em subnet pública | Security groups do EKS só liberam o necessário; API exposta via NLB/API Gateway; RDS `publicly_accessible = false` |
| Mudança de conta na entrega | Código sem valores fixos; procedimento documentado no README |

## Questões resolvidas depois da proposta

- **Observabilidade:** OpenTelemetry Operator neste repositório, com Collector
  exportando para o Datadog a partir do repo #4 (ADR-004).
- **API Gateway:** Traefik dentro do cluster, instalado aqui; rotas via
  `Ingress` no repo #4 (ADR-003).

## Questões em aberto

- O Traefik está exposto por `NodePort`; se a Lambda/API Gateway (repo #1)
  precisar de um endpoint estável, avaliar trocar para `Service` tipo
  `LoadBalancer` (NLB).
- Fixar a versão do chart do Traefik (hoje sem `version`).
