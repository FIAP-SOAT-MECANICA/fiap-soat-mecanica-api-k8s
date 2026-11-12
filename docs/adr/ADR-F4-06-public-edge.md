# ADR-F4-06: Public edge for Phase 4

- Status: Proposed, staged behind `enable_public_nlb`
- Source: Phase 4 plan, F2 and ADR-F4-06

## Decision

An internet-facing Network Load Balancer listens on TCP/80 and forwards to
Traefik's HTTP NodePort 30090 on the EKS managed node group's Auto Scaling
group. The NLB DNS is published at `/${project}/k8s/nlb-dns` in SSM Parameter
Store for the `-auth` repository. Terraform also returns the DNS and parameter
name as outputs.

The NLB has its own security group. The nodes accept NodePort traffic only from
that security group, including when source IP preservation is enabled. This
keeps direct node IP access outside the intended edge path.

`enable_public_nlb` defaults to `false`. Enable it only once all services behind
Traefik validate JWT locally and their ingress rules have been reviewed. A
public NLB is reachable without API Gateway, so the authorizer alone cannot
protect its backend. No API Gateway resources are managed here.

The listener is plain HTTP because TLS terminates at API Gateway. Any direct
NLB caller can still reach the same HTTP endpoint; service-level authorization
is therefore mandatory. The exact parameter name must be agreed with `-auth`
before its deployment.

## Validation at integration time

1. Confirm the AWS Academy account permits NLB and security-group creation.
2. Confirm the EKS node group exposes exactly one Auto Scaling group.
3. Confirm the listener target group becomes healthy and API Gateway reaches a
   test route through the NLB.
4. Confirm requests without valid JWT are rejected by every service even when
   sent directly to the NLB.

This replaces the edge decision in ADR-003 for Phase 4.
