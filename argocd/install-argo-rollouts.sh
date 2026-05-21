#!/bin/bash
set -euo pipefail

echo "=== Installing Argo Rollouts ==="

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install argo-rollouts argo/argo-rollouts \
  --namespace argo-rollouts \
  --create-namespace

echo ""
echo "=== Installing Prometheus (required for canary analysis) ==="

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

echo ""
echo "=== Verifying Helm chart renders correctly ==="

helm template ./helm-chart/argocd-apps --namespace argocd | head -5
echo "... OK"

echo ""
echo "=== Deploy onlineboutique via Helm (with canary support) ==="

helm upgrade --install onlineboutique helm-chart/ \
  --namespace default \
  -f argocd/helm-values/onlineboutique.yaml

echo ""
echo "=== Done ==="
echo ""
echo "Helm is managing:"
echo "  - onlineboutique (all services via Helm chart)"
echo "  - productcatalogservice (canary Rollout + Istio + Analysis)"
echo ""
echo "To start the canary, update the Rollout image in git and sync ArgoCD."
echo "To promote:   kubectl argo rollouts promote productcatalogservice"
echo "To rollback:  kubectl argo rollouts abort productcatalogservice"
echo "To monitor:   kubectl argo rollouts get rollout productcatalogservice --watch"
