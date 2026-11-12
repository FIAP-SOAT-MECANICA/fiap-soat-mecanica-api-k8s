#!/usr/bin/env bash
set -euo pipefail

# Run after Terraform has installed the EKS cluster and OTel Operator.
# Requires a configured kubectl context and DD_API_KEY in the environment.
: "${DD_API_KEY:?Set DD_API_KEY before applying observability resources}"

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

kubectl apply -f "${root_dir}/namespace.yaml"
kubectl apply -f "${root_dir}/otel-rbac.yaml"
printf '%s' "${DD_API_KEY}" |
  kubectl -n mecanica create secret generic otel-datadog-secret \
    --from-file=DD_API_KEY=/dev/stdin --dry-run=client -o yaml |
  kubectl apply -f -
kubectl apply -f "${root_dir}/collector.yaml"
kubectl apply -f "${root_dir}/instrumentation.yaml"

kubectl -n mecanica get opentelemetrycollector otel-daemonset
kubectl -n mecanica get instrumentation java-instrumentation
