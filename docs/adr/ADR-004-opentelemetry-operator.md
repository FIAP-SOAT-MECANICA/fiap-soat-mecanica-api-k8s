# ADR-004: OpenTelemetry Operator como base de observabilidade do cluster

- **Status:** Aceito
- **Data:** 2026-09-15
- **Repositório:** fiap-soat-mecanica-api-k8s
- **Implementação:** `terraform/observability.tf` (PR #4)

## Contexto

O Tech Challenge exige monitoramento e observabilidade — latência das APIs,
CPU e memória do Kubernetes, healthchecks, alertas, logs estruturados com
correlação e dashboards — usando Datadog, New Relic ou equivalente.

A aplicação é Java/Spring Boot. Instrumentá-la manualmente (dependências,
código) em cada serviço seria invasivo e difícil de manter. Além disso, a
ferramenta de destino (Datadog) pode mudar; o grupo queria desacoplar a
coleta do fornecedor.

Restrições do Learner Lab: sem IAM Roles (logo, sem integrações que dependam
de IRSA) e crédito limitado (agentes pesados por node consomem recursos dos
`t3.medium`).

## Decisão

Instalar o **OpenTelemetry Operator** no cluster via Helm
(`helm_release.opentelemetry_operator`, chart oficial, **versão fixada
`0.114.0`**), no namespace `opentelemetry-system`.

O Operator entrega duas coisas:

1. **CRDs** `OpenTelemetryCollector` e `Instrumentation`, que permitem
   declarar coletores e instrumentação como objetos Kubernetes.
2. **Admission webhook** que injeta automaticamente o agente Java do
   OpenTelemetry nos pods anotados — sem alterar a imagem nem o código da
   aplicação.

Configuração relevante:

- `crds.create = true` — o chart gerencia os CRDs.
- `admissionWebhooks.certManager.enabled = false` e
  `autoGenerateCert.enabled = true` — o webhook gera o próprio certificado,
  evitando instalar o cert-manager (menos um componente).
- Imagem do coletor: `otel/opentelemetry-collector-contrib` (inclui o
  exporter do Datadog).
- `atomic`, `cleanup_on_fail`, `wait`, `wait_for_jobs` e `timeout = 300` —
  o `apply` falha limpo se o Operator não ficar `Available`.

**Divisão de responsabilidade:** este repositório instala só o Operator. O
`OpenTelemetryCollector` (com o exporter e a API key do Datadog em `Secret`)
e a `Instrumentation` ficam no repositório da aplicação (#4), no namespace da
própria API. O output `opentelemetry_operator_namespace` indica onde o
Operator está; o #4 só precisa que ele esteja `Available` antes do deploy.

## Consequências

**Positivas**
- Instrumentação sem tocar no código: traces, métricas e logs correlacionados
  por `traceId` — atende o requisito de correlação entre requisições.
- Backend de observabilidade intercambiável: trocar Datadog por New Relic ou
  Grafana é alterar o exporter do Collector, não a aplicação.
- Versão fixada do chart garante reprodutibilidade entre contas.
- Sem IAM: o Collector envia para o Datadog por API key, não por role.

**Negativas / riscos**
- O Operator é um componente a mais no cluster (~200 MiB) e adiciona um
  webhook no caminho de criação de pods; se ele estiver indisponível, pods
  anotados podem falhar ao ser criados.
- Métricas de CPU/memória dos nodes continuam vindo do `metrics-server`
  (ADR-001); o Collector precisa ser configurado para exportá-las ao
  Datadog, ou o painel de recursos do Kubernetes fica incompleto.
- A API key do Datadog é um segredo do repo #4; precisa ser cadastrada na
  conta final.

## Alternativas consideradas

| Alternativa | Motivo da rejeição |
| --- | --- |
| Datadog Agent (DaemonSet via Helm) | Acopla o cluster ao fornecedor; mais pesado por node; instrumentação Java exigiria mudanças na imagem |
| New Relic agent | Mesmo acoplamento; a decisão do grupo já era Datadog |
| Instrumentação manual no código (Micrometer + exporters) | Invasiva, precisa de manutenção a cada serviço novo |
| Prometheus + Grafana no cluster | Consome recursos dos nodes e não atende "Datadog/New Relic ou equivalente" com painel gerenciado |
