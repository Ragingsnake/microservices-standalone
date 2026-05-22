# ArgoCD GitOps

This folder contains the GitOps bootstrap for this repository.

How it works:

1. `argocd/root-app.yaml` is the root Application.
2. The root Application watches `argocd/apps/` in this repo.
3. `argocd/apps/onlineboutique-helm-app.yaml` tells ArgoCD to deploy the Helm chart in `helm-chart/`.
4. `argocd/apps/frontend-canary.yaml` lets Flagger manage the frontend canary rollout through Istio.
5. `argocd/apps/frontend-metric-template.yaml` defines Prometheus queries Flagger uses for success-rate and latency checks. Queries read ingress gateway metrics (`reporter="source"` on `istio-ingressgateway`) so canary analysis works even before workload sidecars are healthy. Flagger renames primary pod labels to `app: frontend-primary`, so the frontend PodMonitor must select both `frontend` and `frontend-primary`. The `onlineboutique` namespace must be labeled `istio.io/rev=default` for sidecar injection.
6. `argocd/apps/frontend-gateway.yaml` exposes the public frontend through the Istio ingress gateway.

What ArgoCD does:

- Continuously compares what is in Git with what is running in the cluster.
- If the live cluster drifts from Git, ArgoCD can show the diff and sync it back.
- If auto-sync is enabled, it will reconcile changes automatically.

How to check it is working:

- Open the ArgoCD dashboard from the workflow output.
- Confirm the root app `microservices-bootstrap` is `Healthy` and `Synced`.
- Confirm the child app `onlineboutique-helm` is also `Healthy` and `Synced`.
- Confirm the `frontend` Canary exists in `onlineboutique` and is progressing or healthy.
- Confirm the Istio `frontend-gateway` exists and the ingressgateway service has a public endpoint.
