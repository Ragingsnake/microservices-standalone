# ArgoCD GitOps

This folder contains the GitOps bootstrap for this repository.

How it works:

1. `argocd/root-app.yaml` is the root Application.
2. The root Application watches `argocd/apps/` in this repo.
3. `argocd/apps/onlineboutique-helm-app.yaml` tells ArgoCD to deploy the Helm chart in `helm-chart/`.

What ArgoCD does:

- Continuously compares what is in Git with what is running in the cluster.
- If the live cluster drifts from Git, ArgoCD can show the diff and sync it back.
- If auto-sync is enabled, it will reconcile changes automatically.

How to check it is working:

- Open the ArgoCD dashboard from the workflow output.
- Confirm the root app `microservices-bootstrap` is `Healthy` and `Synced`.
- Confirm the child app `onlineboutique-helm` is also `Healthy` and `Synced`.
