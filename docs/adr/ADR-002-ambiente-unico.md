# ADR-002: Ambiente único de produção (sem homologação)

- **Status:** Aceito
- **Data:** 2026-09-14
- **Repositório:** fiap-soat-mecanica-api-k8s (infraestrutura Kubernetes)
- **Decisores:** grupo do Tech Challenge — Fase 3

## Contexto

O enunciado do Tech Challenge pede "deploy automático das branches de
homologação e produção". A mensagem oficial do professor reforça: "deverá
existir uma estratégia de deploy automatizado para os ambientes ou branches de
homologação e produção".

A infraestrutura roda em contas do AWS Academy Learner Lab, com as seguintes
restrições relevantes para esta decisão:

- Crédito de aproximadamente **US$ 50 por conta**, não renovável.
- O control plane do EKS custa ~US$ 0,10/h **por cluster**, mesmo ocioso; cada
  node `t3.medium` custa ~US$ 0,04/h.
- Recursos **não são destruídos** ao fim da sessão de 4 horas; um cluster
  esquecido consome crédito continuamente.
- Cada integrante desenvolve na própria conta e, na entrega, tudo é apontado
  para uma única conta.

Dois clusters (homologação + produção) ligados simultaneamente custariam
~US$ 0,36/h — cerca de **US$ 8,60 por dia**, ou seis dias de crédito total.
Isso inviabilizaria os testes de integração entre os quatro repositórios e a
gravação do vídeo.

## Decisão

Manter **um único cluster EKS** (`mecanica`) com **um único namespace de
produção** (`mecanica`), sem ambiente de homologação.

A estratégia de promoção de mudanças passa a ser baseada em **Pull Request**,
não em ambientes:

| Etapa | Onde acontece | O que garante |
| --- | --- | --- |
| Validação | Job `validate` do workflow `Terraform PR` | `fmt`, `validate` — sem tocar na AWS |
| Pré-visualização | Job `plan` do mesmo workflow | O `plan` é comentado no PR; o revisor vê exatamente o que mudará antes do merge |
| Revisão | Branch protection em `main` | Nenhum commit direto; merge só via PR aprovado |
| Deploy | Workflow `Terraform Apply` no merge | Aplicação automática em produção |
| Rollback | Revert do PR + novo merge | O `apply` seguinte desfaz a mudança |

O papel que a homologação teria (validar antes de afetar produção) é cumprido
pelo `plan` comentado no PR e pela revisão obrigatória.

## Consequências

**Positivas**
- Custo reduzido pela metade; viável dentro do crédito do Learner Lab.
- Menos estado para manter sincronizado entre contas durante o desenvolvimento.
- Pipeline mais simples de explicar e demonstrar.

**Negativas / riscos**
- Desvio explícito do enunciado. Este ADR existe para documentar a
  justificativa e deve ser citado na entrega.
- Uma mudança de infraestrutura errada que passe pela revisão afeta produção
  diretamente. Mitigação: `plan` obrigatório no PR, `concurrency` para impedir
  aplicações simultâneas e workflow de `destroy` para recuperação rápida.
- Se o grupo decidir adicionar homologação depois, o Terraform já é
  parametrizável: basta um segundo `backend.hcl` (key `k8s-homolog/...`) e uma
  variável `project = "mecanica-homolog"`. Nenhuma reestruturação é necessária.

## Alternativas consideradas

| Alternativa | Motivo da rejeição |
| --- | --- |
| Dois clusters (homolog + prod) | Custo dobrado; inviável com US$ 50 |
| Um cluster, dois namespaces (homolog + prod) | Isola aplicação mas não infraestrutura; para este repositório (que só cria o cluster) não há o que separar por namespace |
| Homologação efêmera (sobe no PR, destrói no merge) | ~15 min por `apply` + ~10 min por `destroy` a cada PR; sessões de 4h e credenciais rotativas tornam o fluxo frágil |
