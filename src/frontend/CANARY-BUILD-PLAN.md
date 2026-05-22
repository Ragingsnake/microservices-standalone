# Frontend canary image build plan

This guide explains how to build and deploy two demo frontend images for Flagger canary testing:

| Tag | Purpose | Expected canary outcome |
|-----|---------|-------------------------|
| `latest` | Default stable UI (unchanged maroon theme) | Baseline |
| `v2-good` | Winter-themed UI (visual change only) | Promote through weight steps |
| `v2-bad` | Forced HTTP 500 on storefront traffic | Rollback (success rate &lt; 99%) |

Build instructions assume Docker Hub registry `docker.io/ragingsnake` (match your `images.repository` in Helm / ArgoCD).

---

## Helm: point only the frontend at a tag

Other services keep using the global `images.tag` (default `latest` when empty).

```yaml
# helm-chart/values.yaml (or ArgoCD Helm parameters)
images:
  repository: docker.io/ragingsnake
  tag: latest          # all non-frontend services

frontend:
  image:
    tag: v2-good       # only frontend: v2-good | v2-bad | latest | ""
```

**ArgoCD example** (`argocd/apps/onlineboutique-helm-app.yaml`):

```yaml
parameters:
  - name: images.repository
    value: docker.io/ragingsnake
  - name: images.tag
    value: latest
  - name: frontend.image.tag
    value: v2-good     # change to v2-bad for rollback demo
```

Tag resolution order for the frontend container:

1. `frontend.image.tag` if set  
2. else `images.tag` if set  
3. else `latest`

After changing the tag, commit, push, and let ArgoCD sync (or `argocd app sync onlineboutique-helm`). Flagger detects the new deployment revision and starts a canary.

---

## Build and push images

From the repository root, using the GitHub workflow **Build and Push Docker Images**:

1. Apply the code changes for the variant below (`v2-good` or `v2-bad`).
2. Run workflow with **image tag** set to `v2-good` or `v2-bad`.
3. Set **build all images** to `false` if the workflow only builds frontend when changed; otherwise build only frontend via Docker locally:

```bash
cd src/frontend

# v2-good (after winter CSS edits)
docker build -t docker.io/ragingsnake/frontend:v2-good .
docker push docker.io/ragingsnake/frontend:v2-good

# v2-bad (after rollback code edits)
docker build -t docker.io/ragingsnake/frontend:v2-bad .
docker push docker.io/ragingsnake/frontend:v2-bad
```

Keep `latest` pointed at your current stable image for day-to-day use.

---

## v2-good — winter theme (promotion demo)

**Goal:** Obvious visual change so demos can see the canary in the browser. No behavior change; metrics stay healthy.

### Files to edit

| File | What to change |
|------|----------------|
| `static/styles/styles.css` | Replace warm maroon palette with cool winter blues / icy accents |
| `templates/header.html` (optional) | Short banner, e.g. “Winter collection” |
| `handlers.go` (optional) | Set default `FRONTEND_MESSAGE` via env in Helm, not required in image |

### `static/styles/styles.css` — suggested color map

Find-and-replace (verify contrast on buttons after editing):

| Selector / usage | Current | Winter |
|------------------|---------|--------|
| `header` background | `#853B5C` | `#2B5F82` |
| `header .cart-size-circle` background | `#853B5C` | `#2B5F82` |
| `.hottest-item` / hot-deal strip | `#570D2E` | `#1E3A5F` |
| Primary buttons (`.btn-primary` etc.) | `#CE0631` / `#7b031d` | `#4A90B8` / `#2E6F94` |
| Accent / hover pinks | `#f5ccd5`, `#FF9A9B` | `#D6EAF8`, `#A8D4F0` |
| Page background strips | `#F9F9F9` | `#F0F4F8` (slightly cool gray) |

Example header block after edit:

```css
header {
  background-color: #2B5F82;
  color: white;
}
```

### Optional: winter banner without rebuilding logic

In Helm, for the canary rollout only:

```yaml
# Not in image — deployment env (if you add it to frontend chart later)
# env:
#   - name: FRONTEND_MESSAGE
#     value: "Winter sale — canary release"
```

Or add a visible line in `templates/home.html` inside the main container:

```html
<div class="alert alert-info" style="margin: 1rem 0;">❄️ Winter edition (v2-good canary)</div>
```

### Verify v2-good

- Browser: header/buttons are blue-gray, not maroon.
- `curl -s -o /dev/null -w "%{http_code}" http://<INGRESS>/` → `200`
- Canary: Flagger advances weight; success rate stays ≥ 99%.

---

## v2-bad — forced rollback demo

**Goal:** Pods stay **ready** (health checks pass) but **user-facing HTTP** returns **500** so Istio records 5xx and Flagger’s `request-success-rate` (min 99%) fails.

Do **not** break `/_healthz` or readiness will fail before metric analysis.

### Files to edit

| File | What to change |
|------|----------------|
| `handlers.go` | Return 500 on main storefront handlers when demo env is set |
| `main.go` (optional) | Document env var; no change required if only using handlers |

### `handlers.go` — add demo gate

At the top of `package main` vars (after existing `var (` block), add:

```go
canaryRollbackDemo = strings.EqualFold(os.Getenv("CANARY_ROLLBACK_DEMO"), "true")
```

Add a small helper:

```go
func abortCanaryRollbackDemo(w http.ResponseWriter) bool {
	if !canaryRollbackDemo {
		return false
	}
	http.Error(w, "canary rollback demo: intentional failure", http.StatusInternalServerError)
	return true
}
```

Call it at the **start** of each handler that serves real user traffic (not probes):

```go
func (fe *frontendServer) homeHandler(w http.ResponseWriter, r *http.Request) {
	if abortCanaryRollbackDemo(w) {
		return
	}
	// ... existing code
}
```

Repeat for:

- `productHandler`
- `viewCartHandler`
- `addToCartHandler`
- `placeOrderHandler` (optional; homepage traffic is enough for load generator)

**Do not** add the check to:

- `/_healthz` in `main.go`
- `getProductByID` if used only internally

### `main.go` — leave health probe alone

Keep:

```go
r.HandleFunc(baseUrl+"/_healthz", func(w http.ResponseWriter, _ *http.Request) { fmt.Fprint(w, "ok") })
```

Readiness uses `/_healthz` with a cookie; it must keep returning 200.

### Dockerfile — default env for v2-bad image only

For the **v2-bad** build, bake the env into the image so you do not need a separate Helm values file:

```dockerfile
# Add before EXPOSE in Dockerfile (v2-bad branch only)
ENV CANARY_ROLLBACK_DEMO=true
```

For **v2-good** and **latest**, omit that line (or explicitly `ENV CANARY_ROLLBACK_DEMO=false`).

Alternative: set in Helm only when testing bad tag:

```yaml
# Example future enhancement — not required if using ENV in image
# frontend:
#   env:
#     CANARY_ROLLBACK_DEMO: "true"
```

### Verify v2-bad

```bash
# Local run after build
CANARY_ROLLBACK_DEMO=true go run .
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/    # expect 500
curl -s http://localhost:8080/_healthz                              # expect ok
```

In cluster:

- Canary starts progressing, weight may increase briefly.
- Flagger logs: success rate below 99%, failed checks increase, phase **Failed** or rollback.
- `frontend-primary` keeps serving traffic; bad revision not promoted.

---

## Demo runbook

### Successful promotion (v2-good)

1. Build and push `frontend:v2-good` (winter CSS only).
2. Set `frontend.image.tag` to `v2-good`; leave `images.tag` as `latest`.
3. Sync ArgoCD; watch `kubectl -n onlineboutique get canary frontend -w`.
4. Open ingress URL — confirm winter colors on canary share of traffic.

### Rollback (v2-bad)

1. Revert winter/bad code on a branch; apply **v2-bad** edits only; build `frontend:v2-bad`.
2. Set `frontend.image.tag` to `v2-bad`.
3. Sync; confirm Flagger halts and rolls back.
4. Set `frontend.image.tag` back to `latest` (or `v2-good`) to recover.

---

## Reverting source after demos

| Variant | Revert |
|---------|--------|
| v2-good | Restore `static/styles/styles.css` (and any template banner) to original colors |
| v2-bad | Remove `abortCanaryRollbackDemo` helper and handler calls; remove `ENV CANARY_ROLLBACK_DEMO` from Dockerfile |

Then rebuild `latest` from clean tree for normal operations.

---

## Quick reference

```text
src/frontend/
├── Dockerfile              # v2-bad: add ENV CANARY_ROLLBACK_DEMO=true
├── CANARY-BUILD-PLAN.md    # this file
├── handlers.go             # v2-bad: 500 gate on user handlers
├── static/styles/styles.css # v2-good: winter palette
└── templates/home.html     # v2-good: optional banner
```
