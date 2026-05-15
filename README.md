# Microservices Demo: Azure AKS Edition

## Overview
This is a standalone, Azure-optimized version of the classic "Online Boutique" microservices architecture. I initially grabbed this to test out a full 11-tier polyglot application, but I completely gutted the original Google Cloud (GCP) configurations to make it my own.

This repository is purpose-built for deploying to **AWS Elastic Kubernetes Service (EKS)** using an automated CI/CD pipeline. The core philosophy here is fast, reliable testing while keeping infrastructure lifecycle and costs under control.

## The Stack
* **Infrastructure as Code (IaC):** Terraform
* **Automation:** GitHub Actions
* **Cloud Provider:** Azure (specifically `southeastasia` / `eastus` regions)
* **Orchestration:** Kubernetes (AKS)
* **Application:** 11 distinct microservices communicating via gRPC.

## What's Different from the Original?
* **Clean Slate:** Severed the fork from Google. This is a standalone repository completely scrubbed of conflicting GCP Terraform files (`providers.tf`, `memorystore.tf`, etc.).
* **CI/CD (EKS):** The GitHub Actions workflow [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) provisions infrastructure with Terraform and deploys manifests to EKS.
* **Remote State:** Terraform uses a remote state backend (S3/remote state) in CI so runs are consistent and shareable.
* **Controlled Triggers:** The deployment workflow runs only on manual dispatch or if a commit message contains the `[deploy-aws]` tag to avoid accidental cluster provisioning.

## Deployment Overview
This repository supports two common deployment flows: CI-driven EKS provisioning & deploys, and local development with Skaffold.

CI deploy (EKS):

1. Trigger: run the workflow manually via `workflow_dispatch` or push a commit to `main` that includes `[deploy-aws]` in the commit message. See [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) for details.
2. The workflow runs `terraform apply` in `terraform/` to provision the cluster and related resources.
3. After provisioning the cluster, the workflow updates kubeconfig and runs:

    ```bash
    kubectl apply -f release/kubernetes-manifests.yaml
    ```

4. The workflow waits for the `frontend-external` LoadBalancer and exposes the frontend URL in the workflow summary.

Local development (Skaffold / kubectl):

- Use Skaffold for an iterative development loop. Skaffold builds images locally and deploys manifests defined in [skaffold.yaml](skaffold.yaml):

   ```bash
   # Iterative development (rebuilds on change)
   skaffold dev

   # One-shot build-and-deploy
   skaffold run
   ```

- Alternatively, to deploy the release bundle produced by CI locally or in any kubeconfig-aware context:

   ```bash
   kubectl apply -f release/kubernetes-manifests.yaml
   ```

Notes & teardown:

- The repository includes a `terraform/` module used by CI to create infrastructure. To destroy resources created by Terraform, run from the `terraform/` directory:

   ```bash
   terraform destroy -auto-approve
   ```

- A Helm chart is available in [helm-chart/](helm-chart/README.md) for alternative packaging, but CI currently deploys the compiled manifests in `release/`.
