# Observability and Progressive Delivery Demo Guide

This guide matches the cluster you have now.

Current layout:

- `argocd` manages the repo through `microservices-bootstrap` and `onlineboutique-helm`, so Git stays the source of truth
- `monitoring` runs Prometheus and Grafana, which collect and show rollout and traffic metrics
- `istio-system` runs the mesh control plane and ingress gateway, which handle public traffic and service-to-service routing
- `flagger` runs the canary controller, which shifts traffic and judges whether a rollout is healthy
- `onlineboutique` contains the application, the Istio gateway, and the Flagger canary, so it is the workload you will actually change during the demos

Use this as the runbook when you want to demonstrate the platform end to end. Each demo below says what to do, what to watch, and what it proves.

## ArgoCD apps explained

- `microservices-bootstrap` is the parent ArgoCD app. It watches `argocd/apps/` and makes sure the child ArgoCD applications exist in the cluster.
- `onlineboutique-helm` is the child app that deploys Online Boutique from `helm-chart/`. It is the GitOps-managed workload you change during the demos.
- The non-Helm counterpart in this repo is the raw manifest/Kustomize path under `kustomize/` and `kubernetes-manifests/`. Those directories show the same app as plain Kubernetes YAML instead of Helm templates.

In short: `microservices-bootstrap` installs the ArgoCD app definitions, `onlineboutique-helm` installs the workload through Helm, and the non-Helm directories show what the same workload looks like without chart templating.

## What each component does

- **ArgoCD** keeps the repo and the cluster in sync. Change Git, and ArgoCD applies the change.
- **Istio** provides the public ingress gateway and the traffic routing layer for the canary.
- **Prometheus** collects metrics that Flagger uses to judge whether a rollout is healthy.
- **Grafana** visualizes those metrics. In this setup Grafana is exposed over **HTTP**, not HTTPS, so use `http://...` in the browser.
- **Flagger** creates the primary/canary services, shifts traffic, and rolls back bad revisions.

## Stable endpoints and quick checks

Use these whenever you need the live state.

```bash
kubectl get ns
kubectl -n argocd get applications.argoproj.io
kubectl -n istio-system get svc istio-ingressgateway
kubectl -n monitoring get svc monitoring-grafana
kubectl -n onlineboutique get canary,virtualservice,gateway,destinationrule
```

Expected access pattern:

- ArgoCD dashboard comes from the `argocd-server` LoadBalancer
- Grafana comes from the `monitoring-grafana` LoadBalancer over `http://`
- The public frontend comes from the `istio-ingressgateway` LoadBalancer over `http://`

The workflow that prints these endpoints is [`.github/workflows/inspect-cluster.yaml`](../.github/workflows/inspect-cluster.yaml).

## Demo 1: Platform baseline

Goal: prove the platform is installed, explain what each piece is doing, and show ArgoCD correcting a small drift.

What to do:

1. Open ArgoCD and confirm both applications are green.
2. Run the cluster inspection workflow.
3. Open the frontend URL from the inspection output.
4. Open Grafana from the monitoring workflow output or from the `monitoring-grafana` LoadBalancer using `http://`.
5. Create a tiny drift in Git by changing a harmless tracked value, for example toggle `frontend.cymbalBranding` in [`helm-chart/values.yaml`](../helm-chart/values.yaml) from `false` to `true`.

6. Commit and push that change to the branch ArgoCD watches, then wait for ArgoCD to detect the update.

7. Watch ArgoCD mark `onlineboutique-helm` OutOfSync, then sync it back to the Git state from the UI or with the CLI:

    ```bash
    argocd app sync onlineboutique-helm
    ```

8. Confirm the app returns to `Synced` and the frontend reflects the Git change.

What you should see:

- `microservices-bootstrap` is `Synced` and `Healthy`
- `onlineboutique-helm` is `Synced` and `Healthy`
- the `frontend` canary exists in `onlineboutique`
- the `frontend-gateway` exists in `onlineboutique`
- `istio-ingressgateway` has a public address
- Grafana opens successfully only over `http://`
- the repo changes first, then the live `onlineboutique-helm` app drifts and returns to `Synced` after ArgoCD applies the desired state

What this proves:

- GitOps is active
- ArgoCD is the control point for desired state, not the running cluster
- Istio ingress is reachable
- Monitoring is live
- Flagger has initialized the canary wiring
- a small Git change can be corrected by syncing back to Git

Helpful commands:

```bash
kubectl -n argocd get applications.argoproj.io
kubectl -n onlineboutique get canary frontend -o yaml
kubectl -n onlineboutique get virtualservice frontend -o yaml
kubectl -n istio-system get svc istio-ingressgateway
kubectl -n onlineboutique get deploy frontend
```

## Demo 2: Successful canary promotion

Goal: prove that a healthy new frontend revision is promoted automatically.

What to prepare:

- Publish a new frontend image tag to Docker Hub, for example `v2-good`
- Update `argocd/apps/onlineboutique-helm-app.yaml` so `images.tag` points to that new tag
- Commit and push that change to `main`

Why this route matters:

- The Helm app is the source of truth for the workload image tag
- ArgoCD applies the change
- Flagger sees the deployment revision change and runs the canary

What to watch:

```bash
kubectl -n argocd get application onlineboutique-helm -w
kubectl -n onlineboutique get canary frontend -w
kubectl -n onlineboutique describe canary frontend
kubectl -n onlineboutique get deploy,rs,pod,svc | grep frontend
kubectl -n flagger logs deploy/flagger -f
```

What a successful rollout looks like:

- the canary moves from `Initialized` to `Progressing`
- the canary weight increases in steps
- Flagger reports the metrics as healthy
- the canary ends in `Succeeded`
- the new frontend revision becomes the promoted release

What this proves:

- ArgoCD can drive a version change from Git
- Istio is routing through the mesh gateway
- Flagger can safely promote a good release
- the old and new services stay isolated during the rollout

To make the promotion obvious, keep traffic flowing while the rollout happens:

```bash
kubectl -n onlineboutique logs deploy/loadgenerator -f
```

## Demo 3: Canary rollback

Goal: prove that Flagger stops a bad release and keeps the last good version serving traffic.

What to prepare:

- Publish a deliberately bad frontend tag, for example `v2-bad`
- Update `argocd/apps/onlineboutique-helm-app.yaml` so `images.tag` points to that bad tag
- Commit and push the change to `main`

Two easy ways to make a bad tag:

1. Build an image that starts but returns HTTP 500 for `/`
2. Use a tag that never becomes ready and fails startup, if you want a faster failure demo

What to watch:

```bash
kubectl -n onlineboutique get canary frontend -w
kubectl -n onlineboutique describe canary frontend
kubectl -n onlineboutique get events --sort-by=.lastTimestamp
kubectl -n onlineboutique get deploy,rs,pod,svc | grep frontend
kubectl -n flagger logs deploy/flagger -f
```

What a rollback looks like:

- the canary starts to progress, then fails health checks or readiness
- Flagger records failed checks
- the canary ends in `Failed` or rolls back without promotion
- the stable `frontend-primary` path keeps serving traffic
- the bad revision does not become the promoted workload

What this proves:

- Flagger is protecting you from a bad release
- the stable service stays available while the bad version is rejected
- the mesh and canary plumbing are controlling traffic correctly

If you use a bad image that still starts, keep a steady stream of requests so Flagger has enough signal to evaluate the metrics.

## Demo 4: Traffic and metrics under load

Goal: show the mesh and monitoring reacting to live traffic.

What to do:

1. Leave the load generator running, or start Locust from your laptop.
2. Open Grafana over the `http://` URL from the workflow output.
3. Watch the canary rollout or rollback while traffic is flowing.

Locust example:

```python
from locust import HttpUser, task, between


class FrontendUser(HttpUser):
    wait_time = between(1, 2)

    @task
    def index(self):
        self.client.get("/")
```

Run it from your machine with the Istio ingress hostname from the inspection workflow:

```bash
LOCUST_HOST=http://<ISTIO_INGRESS_HOST>
locust -f locustfile.py --host "$LOCUST_HOST" --users 50 --spawn-rate 10 --run-time 3m --headless
```

What to watch in parallel:

```bash
kubectl -n onlineboutique get canary frontend -w
kubectl -n monitoring get pods
kubectl -n monitoring get svc monitoring-grafana
```

What this proves:

- traffic is flowing through Istio ingress
- Prometheus and Grafana are collecting and visualizing the rollout
- Flagger reacts to traffic and metric changes, not just static state

## Suggested demo order

If you want the cleanest presentation, run them in this order:

1. Platform baseline
2. Successful canary promotion
3. Canary rollback
4. Traffic and metrics under load

That order shows the full lifecycle: install, healthy rollout, failure handling, and live observability.

## Cleanup

When you are done, use the destroy workflow to remove the cluster and all namespaces. That is the low-friction way to avoid charges.

If you only want to remove the demo stack but keep the cluster for another run, delete the demo workloads and namespaces first:

```bash
kubectl delete canary frontend -n onlineboutique
kubectl delete namespace onlineboutique monitoring flagger istio-system argocd
```
