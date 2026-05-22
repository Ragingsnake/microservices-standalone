# Microservices Standalone — Architecture

Repo: https://github.com/Ragingsnake/microservices-standalone

A standalone fork of Google's "Online Boutique" 11-tier polyglot microservices demo, repurposed to deploy on **AWS EKS** via **Terraform** + **GitHub Actions**. (An older Azure AKS backup config also exists in `terraform/backup/`.)

---

## 1. Infrastructure (Terraform — `terraform/main.tf`)

**Provider:** AWS, region `ap-southeast-1`
**Backend:** S3 remote state (configured via `-backend-config`)

### AWS resources provisioned

| Layer | Resource | Notes |
|---|---|---|
| Networking | `aws_vpc.main` | CIDR `10.0.0.0/16`, DNS hostnames + support enabled |
| Networking | `aws_internet_gateway.main` | Public internet egress |
| Networking | `aws_subnet.public_a` | `10.0.1.0/24`, AZ `ap-southeast-1a`, auto-assign public IP, tagged for ELB |
| Networking | `aws_subnet.public_b` | `10.0.2.0/24`, AZ `ap-southeast-1b`, auto-assign public IP, tagged for ELB |
| Networking | `aws_route_table.public` + 2 associations | Default route → IGW |
| IAM | `aws_iam_role.eks_cluster` | Trusts `eks.amazonaws.com`; attached: `AmazonEKSClusterPolicy` |
| IAM | `aws_iam_role.eks_node_group` | Trusts `ec2.amazonaws.com`; attached: `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly` |
| Compute | `aws_eks_cluster.eks` (`microservices-eks`) | Control plane in the two public subnets |
| Compute | `aws_eks_node_group.default` | `t3.medium`, AL2023 x86_64, scaling 2/2/3 (desired/min/max) |
| Lifecycle | `null_resource.k8s_destroy_cleanup` | On `destroy`, runs `kubectl delete -f release/kubernetes-manifests.yaml` so LoadBalancer ENIs free up before subnets are torn down |

### CI/CD (`.github/workflows/deploy.yml`)
- Triggered by `workflow_dispatch` or commit message containing `[deploy-aws]`.
- Runs `terraform apply` in `terraform/`.
- Updates kubeconfig, then `kubectl apply -f release/kubernetes-manifests.yaml`.
- Waits for `frontend-external` LoadBalancer; surfaces URL in workflow summary.

---

## 2. Application (11 microservices on EKS)

Polyglot services communicating over **gRPC**, with the `frontend` exposed as a Kubernetes `LoadBalancer` (`frontend-external`) backed by an AWS ELB.

| Service | Language | Role |
|---|---|---|
| frontend | Go | HTTP server; entrypoint; calls all other services |
| cartservice | C# (.NET) | User shopping cart |
| productcatalogservice | Go | Product list / lookup |
| currencyservice | Node.js | Currency conversion |
| paymentservice | Node.js | Charges card (mocked) |
| shippingservice | Go | Shipping quote + order |
| emailservice | Python | Sends order confirmation (mocked) |
| checkoutservice | Go | Orchestrates cart → payment → shipping → email |
| recommendationservice | Python | Product recommendations |
| adservice | Java | Contextual ads |
| loadgenerator | Python (Locust) | Synthetic traffic for testing |
| shoppingassistantservice | Python | LLM-powered assistant (optional) |

### Call graph (gRPC unless noted)

```
                user ──HTTP──► frontend
                                  │
   ┌────────────┬────────┬────────┼──────────┬──────────────┬────────────┐
   ▼            ▼        ▼        ▼          ▼              ▼            ▼
 productcatalog currency  cart  recommendation  ad      checkout      shipping
                                                          │
                          ┌───────────────┬───────────────┼────────────┐
                          ▼               ▼               ▼            ▼
                       payment        email         productcatalog   currency
                                                       + cart + shipping
loadgenerator ──HTTP──► frontend (synthetic load)
```

---

## 3. Deployment artifacts

- `release/kubernetes-manifests.yaml` — bundled Deployments + Services applied by CI.
- `helm-chart/` — equivalent Helm chart per service.
- `kustomize/` — Kustomize overlays.
- `istio-manifests/` — optional Istio gateway/virtualservice for the frontend.
- `skaffold.yaml` — local iterative dev loop (`skaffold dev` / `skaffold run`).

---

## 4. End-to-end request path

1. Client hits the **AWS ELB** (Classic/NLB) provisioned by the `frontend-external` `Service` of type `LoadBalancer`.
2. ELB forwards to a `frontend` pod on an EKS worker node (in `public_a`/`public_b`).
3. `frontend` fans out gRPC calls inside the cluster (ClusterIP services) to catalog/cart/currency/ad/recommendation.
4. On checkout, `frontend → checkoutservice → {payment, shipping, email, productcatalog, currency, cart}`.
5. `loadgenerator` (in-cluster) drives synthetic traffic against `frontend`.

See `architecture.drawio` for the diagram.
