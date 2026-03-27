# Microservices Demo: Azure AKS Edition

## Overview
This is a standalone, Azure-optimized version of the classic "Online Boutique" microservices architecture. I initially grabbed this to test out a full 11-tier polyglot application, but I completely gutted the original Google Cloud (GCP) configurations to make it my own.

This repository is purpose-built for deploying to **Azure Kubernetes Service (AKS)** using a fully automated CI/CD pipeline. The core philosophy here is fast, reliable testing without letting infrastructure sit around and passively eat up cloud credits. 

## The Stack
* **Infrastructure as Code (IaC):** Terraform
* **Automation:** GitHub Actions
* **Cloud Provider:** Azure (specifically `southeastasia` / `eastus` regions)
* **Orchestration:** Kubernetes (AKS)
* **Application:** 11 distinct microservices communicating via gRPC.

## What's Different from the Original?
* **Clean Slate:** Severed the fork from Google. This is a standalone repository completely scrubbed of conflicting GCP Terraform files (`providers.tf`, `memorystore.tf`, etc.).
* **Azure Pipeline:** Built a custom `.github/workflows/deploy.yml` that securely authenticates with Azure, provisions the cluster, and applies the Kubernetes manifests.
* **Centralized State:** Configured a remote Terraform state using an Azure Storage Account so the automated GitHub workers have a consistent memory of the infrastructure.
* **Controlled Triggers:** The deployment pipeline is intentionally strict. It only runs if a commit message explicitly contains the `[deploy-azure]` tag, preventing accidental spin-ups.

## The "Zero Risk" Deployment Cycle
Because AKS clusters and Load Balancers are expensive to leave idling, this workflow is designed to be spun up, tested, and destroyed quickly. 

1. **Deploy:** Push a commit to `main` with `[deploy-azure]`. GitHub Actions handles the rest.
2. **Test:** Fetch the `EXTERNAL-IP` of the `frontend-external` service via `kubectl` to verify the live site.
3. **Annihilate:** Once testing is quickly over, immediately run the teardown commands to wipe the Azure resource groups clean and prevent passive billing:
   ```bash
   az group delete --name microservices-demo-rg --yes --no-wait
   az group delete --name tfstate-sea-rg --yes --no-wait
