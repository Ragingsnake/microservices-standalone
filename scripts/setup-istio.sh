#!/bin/bash
set -euo pipefail

ISTIO_VERSION="${ISTIO_VERSION:-1.24.3}"
NAMESPACE="${NAMESPACE:-onlineboutique}"

echo "==> Downloading Istio $ISTIO_VERSION..."
curl -sL https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
ISTIO_DIR="istio-$ISTIO_VERSION"
export PATH=$PATH:./$ISTIO_DIR/bin

echo "==> Installing Istio (demo profile)..."
istioctl install --set profile=demo -y

echo "==> Installing Prometheus addon..."
kubectl apply -f $ISTIO_DIR/samples/addons/prometheus.yaml

echo "==> Installing Kiali addon..."
kubectl apply -f $ISTIO_DIR/samples/addons/kiali.yaml

echo "==> Waiting for Kiali to be ready..."
kubectl rollout status deployment/kiali -n istio-system --timeout=120s

echo "==> Labeling namespace '$NAMESPACE' for sidecar injection..."
kubectl label namespace "$NAMESPACE" istio-injection=enabled --overwrite

echo ""
echo "=============================================="
echo "Done!"
echo "  Kiali: kubectl port-forward svc/kiali 20001:20001 -n istio-system"
echo "=============================================="
