# ADR-001: Estratégia de escalabilidade do cluster e da aplicação

- **Status:** Aceito
- **Data:** 2026-09-14
- **Repositório:** fiap-soat-mecanica-api-k8s (infraestrutura Kubernetes)
- **Decisores:** grupo do Tech Challenge — Fase 3

## Contexto

O Tech Challenge exige "cluster Kubernetes com escalabilidade" e cita o uso de
HPA como exemplo de decisão arquitetural permanente. A aplicação (Spring Boot)
já define, desde a Fase 2, `requests` de 250m CPU / 512Mi e um HPA que varia de
2 a 5 réplicas por CPU e memória a 70%.

O ambiente é o AWS Academy Learner Lab, que impõe: impossibilidade de criar IAM
Roles (logo, sem IRSA), crédito de ~US$ 50 por conta e sessões de 4 horas. Isso
elimina soluções que dependem de roles dedicadas ou de custo fixo alto.

Há duas camadas de escalabilidade a decidir:

1. **Pods** — quantas réplicas da API rodam.
2. **Nodes** — quantas máquinas EC2 existem para hospedar os pods.

## Decisão

### Camada de pods: HPA por CPU e memória, com metrics-server como addon do EKS

- O HPA continua sendo responsabilidade do repositório da aplicação (#4), que
  conhece o perfil de carga da API.
- Este repositório garante o pré-requisito: o addon gerenciado `metrics-server`
  é instalado pelo Terraform (`eks-addons.tf`) e depende do node group estar
  pronto. Sem ele, o HPA fica em `<unknown>` e nunca escala.
- Optou-se pelo addon gerenciado em vez do manifesto vendorizado da Fase 2,
  que continha a flag `--kubelet-insecure-tls`, específica do Kind e inadequada
  para EKS.

### Camada de nodes: managed node group EC2 com faixa fixa (min 1, desired 2, max 3)

- Tipo `t3.medium` (2 vCPU / 4 GiB). Dois nodes comportam as 5 réplicas máximas
  da API (5 × 250m = 1,25 vCPU; 5 × 512Mi = 2,5 GiB) mais os pods de sistema.
- `max_size = 3` dá margem para crescimento manual (ou futuro Cluster Autoscaler)
  sem estourar o crédito.
- `ignore_changes` em `desired_size` evita que um `terraform apply` desfaça um
  ajuste manual ou automático de capacidade.
- **Não** foi adotado o Cluster Autoscaler nem o Karpenter nesta fase: ambos
  precisam de IAM Role própria (IRSA ou Pod Identity), o que o Learner Lab não
  permite criar. O node group com `max_size` já cumpre o requisito de
  escalabilidade de infraestrutura para o volume esperado de demonstração.

### Fargate foi descartado

Fargate elimina a gestão de nodes, mas: exige pod execution role (IAM), tem
cold start maior para a JVM, não permite `kubectl top nodes` nem DaemonSets
(inviabilizando agentes de observabilidade) e o HPA exigiria configuração
adicional de métricas. EC2 é mais simples de demonstrar e de monitorar.

## Consequências

**Positivas**
- Escalabilidade demonstrável em vídeo: `kubectl top nodes` prova o
  metrics-server; carga na API faz o HPA subir réplicas.
- Nenhuma dependência de IAM além da `LabRole` pré-existente.
- Custo previsível: no máximo 3 × t3.medium.

**Negativas / riscos**
- Se o HPA levar a API a 5 réplicas e outros workloads (agente de
  observabilidade, ingress) consumirem recursos, pode faltar capacidade —
  mitigado pelo `max_size = 3`, ajustável manualmente.
- Escalonamento de nodes não é automático; exige `terraform apply` com novo
  `node_desired_size` ou ajuste no console. Aceitável para o escopo acadêmico.

## Alternativas consideradas

| Alternativa | Motivo da rejeição |
| --- | --- |
| Cluster Autoscaler | Requer IAM Role dedicada (IRSA) — não permitido no Learner Lab |
| Karpenter | Mesma restrição de IAM, além de complexidade maior |
| Fargate | Sem DaemonSets, cold start da JVM, IAM para pod execution role |
| metrics-server via manifesto YAML | Manutenção manual e flag insegura herdada do Kind |
