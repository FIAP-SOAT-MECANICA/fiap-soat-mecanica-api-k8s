# fiap-soat-mecanica-api-k8s

Infraestrutura Kubernetes da Mecânica do Braia, provisionada com Terraform na AWS
(EKS). Este é o repositório **#2** do Tech Challenge — Fase 3 (FIAP SOAT):

1. Lambda — função serverless de autenticação por CPF
2. **Infraestrutura Kubernetes (Terraform)**
3. Infraestrutura do banco de dados gerenciado (Terraform)
4. Aplicação principal executando em Kubernetes
   ([fiap-soat-mecanica-api](https://github.com/FIAP-SOAT-MECANICA/fiap-soat-mecanica-api))

## Objetivo

Criar e manter o cluster EKS onde a API da oficina roda, com escalabilidade
(managed node group + metrics-server para HPA), e expor os dados que os demais
repositórios precisam para se conectar a ele (VPC, security group, nome do
cluster, comando de kubeconfig).

## Tecnologias

- Terraform >= 1.10 (backend S3 com lock nativo, sem DynamoDB)
- AWS EKS (control plane gerenciado)
- AWS EKS Managed Node Group (EC2 `t3.medium`)
- EKS Addon `metrics-server`
- Traefik (Helm release) como API Gateway do cluster — controla e roteia as requisições até os services das aplicações
- OpenTelemetry Operator (Helm release) — CRDs `OpenTelemetryCollector`/`Instrumentation` e o admission webhook que injeta o agente Java nos pods das aplicações
- EKS Access Entries (autenticação `API_AND_CONFIG_MAP`, admin automático para quem cria o cluster)
- GitHub Actions

## Arquitetura

```mermaid
flowchart LR
  GH[GitHub Actions] -->|terraform apply| TF[Terraform]
  TF --> S3[(S3: state)]
  TF --> EKS[EKS control plane]
  EKS --> NG[Managed node group\n2x t3.medium, min 1 / max 3]
  EKS --> MS[Addon metrics-server]
  MS --> HPA[HPA da API\nrepo #4]
  EKS --> TR[Helm release Traefik\nAPI Gateway do cluster]
  EKS --> OTEL[Helm release OpenTelemetry Operator\nCRDs + admission webhook]
  subgraph VPC default da conta
    NG
  end
  RDS[(RDS - repo #3)] -. 5432 liberado para o SG do cluster .-> NG
  API[Deployment da API - repo #4] -. kubectl apply .-> NG
  API -. Ingress .-> TR
  TR -. roteia e controla as requisicoes .-> API
  API -. Collector + Instrumentation .-> OTEL
  OTEL -. injeta agente Java .-> API
```

## Restrições do AWS Academy Learner Lab

Este projeto roda em contas do AWS Academy. Isso impõe regras que explicam
várias decisões do código:

| Restrição | Consequência no projeto |
| --- | --- |
| Não é possível criar IAM Roles | Cluster e nodes usam a role pré-existente `LabRole` |
| A sessão assume a role `voclabs` | O cluster é criado com `bootstrap_cluster_creator_admin_permissions = true`, então `voclabs` (quem roda o `apply`) recebe admin automaticamente e o `kubectl` funciona em qualquer sessão da conta |
| Credenciais (access key, secret, session token) expiram a cada ~4h | Precisam ser renovadas no `~/.aws/credentials` local e nos GitHub Secrets antes de cada uso |
| Recursos **não** são apagados quando a sessão termina | Rode `terraform destroy` ao encerrar o dia |
| Crédito de ~US$ 50 por conta | EKS cobra ~US$ 0,10/h pelo control plane mesmo ocioso; mantenha o cluster ligado só quando necessário |
| Região limitada | Tudo em `us-east-1` |
| EKS não aceita control plane na AZ `us-east-1e` | A subnet dessa AZ é excluída automaticamente |

Cada integrante desenvolve na própria conta; na entrega final tudo é apontado
para uma única conta. Por isso **nenhum account ID, ARN ou nome de bucket é
hardcoded**: o `account_id` vem da sessão ativa e o backend vem de um arquivo
local ignorado pelo Git.

## Estrutura

```text
.
├── bootstrap/
│   └── create-state-bucket.sh  
└── terraform/
    ├── versions.tf              
    ├── backend.tf               
    ├── backend.hcl.example      
    ├── providers.tf             
    ├── variables.tf             
    ├── locals.tf                
    ├── data.tf                  
    ├── eks-cluster.tf           
    ├── eks-node.tf              
    ├── eks-addons.tf            
    └── outputs.tf            
```

## Pré-requisitos

- Terraform >= 1.10
- AWS CLI v2
- kubectl
- Sessão ativa do AWS Academy Learner Lab

## Como executar

### 1. Credenciais do Learner Lab

No Learner Lab, clique em **AWS Details → AWS CLI → Show** e cole o bloco em
`~/.aws/credentials`. Confirme:

```bash
aws sts get-caller-identity
```

### 2. Bucket de state (uma vez por conta)

```bash
./bootstrap/create-state-bucket.sh
```

O script cria `mecanica-tfstate-<account-id>` com versionamento, bloqueio de
acesso público e criptografia, e imprime o conteúdo do `backend.hcl`.

### 3. Backend local

```bash
cp terraform/backend.hcl.example terraform/backend.hcl
# edite o bucket com o valor impresso pelo bootstrap
```

`backend.hcl` é ignorado pelo Git porque muda por conta.

### 4. Provisionar

```bash
cd terraform
terraform init -backend-config=backend.hcl
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

O `apply` leva cerca de 15 minutos (control plane ~10 min, node group ~5 min).

### 5. Validar

```bash
$(terraform output -raw kubeconfig_command)
kubectl get nodes
kubectl top nodes            # garante que o metrics-server está ativo
kubectl get addon -A 2>/dev/null || aws eks list-addons --cluster-name mecanica
```

### 6. Destruir ao encerrar o dia

```bash
terraform destroy
```

## Outputs (contrato com os outros repositórios)

| Output | Quem usa | Para quê |
| --- | --- | --- |
| `vpc_id` | #3 (RDS) | Criar o RDS na mesma VPC |
| `cluster_security_group_id` | #3 (RDS) | Liberar a porta 5432 apenas para os nodes |
| `subnet_ids` | #3 (RDS) | Subnet group do RDS |
| `cluster_name`, `region`, `kubeconfig_command` | #4 (API) | Configurar o kubectl na pipeline de deploy |
| `cluster_endpoint`, `cluster_certificate_authority` | #4 (API) | Alternativa ao `update-kubeconfig` |
| `traefik_namespace` | #4 (API) | Namespace do gateway; a API aplica um `Ingress` apontando pro Service `traefik` nesse namespace |
| `opentelemetry_operator_namespace` | #4 (API) | Namespace do OpenTelemetry Operator; a API aplica o `OpenTelemetryCollector`/`Instrumentation` no proprio namespace, so precisa que o Operator esteja `Available` aqui antes |

Leitura via remote state:

```hcl
data "terraform_remote_state" "k8s" {
  backend = "s3"
  config = {
    bucket = "mecanica-tfstate-<account-id>"
    key    = "k8s/terraform.tfstate"
    region = "us-east-1"
  }
}
```

## Pipeline (GitHub Actions)

Três workflows em `.github/workflows/`:

| Workflow | Gatilho | O que faz |
| --- | --- | --- |
| `terraform-pr.yml` | Pull request para `main` | Job `validate`: `fmt -check`, `init -backend=false`, `validate` (não precisa de AWS). Job `plan`: `init` no bucket da conta + `plan`, com a saída comentada no PR. Só roda se os secrets existirem |
| `terraform-apply.yml` | Push em `main` que altere `terraform/**` (ou manual) | `init`, `validate`, `plan`, `apply` e imprime os outputs |
| `terraform-destroy.yml` | Manual (`workflow_dispatch`) | Pede a confirmação `destroy` e executa `terraform destroy` — controle de custo no Learner Lab |

Os três compartilham o grupo de concorrência `terraform-state`, então nunca há
dois `plan`/`apply`/`destroy` rodando ao mesmo tempo sobre o mesmo state.

### Como o backend é resolvido na pipeline

Não existe secret com nome de bucket nem account ID. O workflow descobre a
conta ativa com `aws sts get-caller-identity` e monta
`mecanica-tfstate-<account-id>` na hora. O mesmo workflow funciona na conta de
qualquer integrante e na conta final — basta trocar os secrets.

### Secrets necessários (Settings → Secrets and variables → Actions)

| Secret | Origem |
| --- | --- |
| `AWS_ACCESS_KEY_ID` | Learner Lab → AWS Details → AWS CLI → Show |
| `AWS_SECRET_ACCESS_KEY` | idem |
| `AWS_SESSION_TOKEN` | idem |

Os três **expiram a cada ~4h** junto com a sessão do lab. Se um workflow
falhar com `ExpiredToken` ou `InvalidClientTokenId`, não é bug: renove os três
secrets e execute de novo (`Re-run jobs`).

### Fluxo típico de um dia de trabalho

1. Start Lab → copiar credenciais → atualizar os 3 secrets.
2. Abrir PR → conferir o comentário do `plan`.
3. Merge → `terraform-apply.yml` sobe o cluster.
4. Fim do dia → Actions → `Terraform Destroy` → `Run workflow` → digitar `destroy`.
5. End Lab.
