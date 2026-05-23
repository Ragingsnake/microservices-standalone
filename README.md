# Microservices Demo: AWS EKS Edition

## Overview
This is a standalone, AWS EKS-focused version of the classic "Online Boutique" microservices architecture. I initially grabbed this to test out a full 11-tier polyglot application, but I completely gutted the original Google Cloud (GCP) and Azure-specific configurations to make it my own.

This repository is purpose-built for deploying to **AWS Elastic Kubernetes Service (EKS)** using an automated GitHub Actions CI/CD pipeline. The core philosophy here is fast, reliable testing while keeping infrastructure lifecycle and costs under control.

## The Stack
* **Infrastructure as Code (IaC):** Terraform
* **Automation:** GitHub Actions
* **Cloud Provider:** AWS (EKS)
* **Orchestration:** Kubernetes (EKS)
* **Application:** 11 distinct microservices communicating via gRPC.

## What's Different from the Original?
* **Clean Slate:** Severed the fork from Google. This is a standalone repository completely scrubbed of conflicting GCP Terraform files (`providers.tf`, `memorystore.tf`, etc.).
* **CI/CD (EKS):** The GitHub Actions workflow [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) provisions infrastructure with Terraform and deploys manifests to EKS.
* **Remote State:** Terraform uses a remote state backend (S3/remote state) in CI so runs are consistent and shareable.
* **Controlled Triggers:** The deployment workflow runs on pushes to `main` and manual dispatch, but the provisioning step only executes when the workflow is manually triggered or the commit message contains `[deploy-aws]`.

## Deployment Overview
This repository supports two common deployment flows: CI-driven EKS provisioning and deployment, and local development with Skaffold.

CI deploy (EKS):

1. Trigger: run the workflow manually via `workflow_dispatch` or push a commit to `main` that includes `[deploy-aws]` in the commit message. See [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) for details.
2. The workflow runs `terraform apply` in `terraform/` to provision or update AWS infrastructure.
3. After provisioning, the workflow updates kubeconfig and boots cluster components using the `setup-istio`, `setup-monitoring`, `setup-flagger`, and `setup-argocd` workflows.
4. The application is deployed through ArgoCD, and the workflow waits for the Istio frontend endpoint before publishing the URL.

Local development (Skaffold / kubectl):

- Use Skaffold for an iterative development loop. Skaffold builds images locally and deploys manifests defined in [skaffold.yaml](skaffold.yaml):

   ```bash
   # Iterative development (rebuilds on change)
   skaffold dev

   # One-shot build-and-deploy
   skaffold run
   ```

- Alternatively, to deploy a prebuilt release bundle manually in any kubeconfig-aware context:

   ```bash
   kubectl apply -f release/kubernetes-manifests.yaml
   ```

Notes & teardown:

- The repository includes a `terraform/` module used by CI to create infrastructure. To destroy resources created by Terraform, run from the `terraform/` directory:

   ```bash
   terraform destroy -auto-approve
   ```

- A Helm chart is available in [helm-chart/](helm-chart/README.md) for alternative packaging, but CI currently deploys the compiled manifests in `release/`.
