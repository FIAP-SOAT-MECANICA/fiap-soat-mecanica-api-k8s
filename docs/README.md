# Documentação — infraestrutura Kubernetes

Decisões e justificativas do repositório `fiap-soat-mecanica-api-k8s`
(repositório #2 do Tech Challenge — Fase 3). A documentação transversal da
solução (diagrama de componentes geral, diagramas de sequência, modelo ER e
RFCs de nuvem/banco/autenticação) fica no local definido pelo grupo; aqui
estão apenas as decisões que existem por causa deste componente.

## RFCs

| Documento | Assunto |
| --- | --- |
| [RFC-001](rfc/RFC-001-eks-learner-lab.md) | Provisionar o cluster com EKS no AWS Academy Learner Lab: restrições, alternativas, custo, validação |

## ADRs

| Documento | Decisão |
| --- | --- |
| [ADR-001](adr/ADR-001-escalabilidade.md) | Escalabilidade: HPA por CPU/memória com metrics-server + managed node group EC2 (min 1 / max 3) |
| [ADR-002](adr/ADR-002-ambiente-unico.md) | Um único cluster e ambiente de produção, sem homologação; promoção via PR com `plan` comentado |
| [ADR-003](adr/ADR-003-traefik-api-gateway.md) | Traefik (Helm, `NodePort`) como API Gateway dentro do cluster; `Ingress` fica no repo da aplicação |
| [ADR-004](adr/ADR-004-opentelemetry-operator.md) | OpenTelemetry Operator (Helm, v0.114.0) como base de observabilidade; Collector e Instrumentation ficam no repo da aplicação |

## Diagrama do componente

O diagrama específico deste repositório está na seção
[Arquitetura](../README.md#arquitetura) do README principal.

## Convenções

- **RFC** registra uma proposta com alternativas comparadas, custo e riscos —
  escrita antes ou durante a decisão.
- **ADR** registra uma decisão já tomada: contexto, decisão, consequências.
  ADRs não são editados depois de aceitos; uma mudança gera um novo ADR que
  substitui o anterior.
- Numeração sequencial por tipo. Próximos: `RFC-002`, `ADR-005`.
