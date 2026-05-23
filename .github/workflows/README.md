# GitHub Actions Workflows

This page describes the CI/CD workflows for the Online Boutique app, which run in [Github Actions](https://github.com/GoogleCloudPlatform/microservices-demo/actions).

## Infrastructure

The CI/CD pipelines for Online Boutique run in Github Actions, using a pool of two [self-hosted runners]((https://help.github.com/en/actions/automating-your-workflow-with-github-actions/about-self-hosted-runners)). These runners are GCE instances (virtual machines) that, for every open Pull Request in the repo, run the code test pipeline, deploy test pipeline, and (on main) deploy the latest version of the app to [cymbal-shops.retail.cymbal.dev](https://cymbal-shops.retail.cymbal.dev)

We also host a test GKE cluster, which is where the deploy tests run. Every PR has its own namespace in the cluster.

## Workflows

**Note**: In order for the current CI/CD setup to work on your pull request, you must branch directly off the repo (no forks). This is because the Github secrets necessary for these tests aren't copied over when you fork.

### Code Tests - [ci-pr.yaml](ci-pr.yaml)

This workflow runs on pull requests targeting `main` and performs repository-level CI checks, including Go and C# unit tests.

### Deploy Tests - [ci-pr.yaml](ci-pr.yaml)

This workflow also contains a PR deployment stage that builds and deploys the current PR to a test cluster using `skaffold run`. It then verifies the application pods startup, obtains the frontend staging endpoint, and reports that endpoint back to the PR.

### Deploy to AWS EKS - [deploy.yml](deploy.yml)

This workflow controls production deployment and infrastructure provisioning. It is triggered on pushes to `main` and via manual dispatch, but the deployment job only runs when the workflow is manually triggered or the head commit message contains `[deploy-aws]`.

This workflow:

1. Provisions or updates AWS EKS infrastructure using Terraform.
2. Updates the kubeconfig for the target EKS cluster.
3. Installs or configures ArgoCD, Istio, monitoring, and Flagger.
4. Deploys the microservices via ArgoCD.
5. Waits for the frontend ingress endpoint and outputs the deployment URL.

### Build and Push Docker Images - [docker-build-push.yml](docker-build-push.yml)

This workflow detects changed services and builds only the affected Docker images. It can also be manually triggered to rebuild all images.

### Cleanup - [cleanup.yaml](cleanup.yaml)

This workflow runs when a PR closes, regardless of whether it was merged into main. This workflow deletes the PR-specific GKE namespace in the test cluster.

## Appendix - Creating a new Actions runner

Should one of the two self-hosted Github Actions runners (GCE instances) fail, or you want to add more runner capacity, this is how to provision a new runner. Note that you need IAM access to the admin Online Boutique GCP project in order to do this.

1. Create a GCE instance.
    - VM should be at least n1-standard-4 with 50GB persistent disk
    - VM should use custom service account with permissions to: access a GKE cluster, create GCS storage buckets, and push to GCR.
2. SSH into new VM through the Google Cloud Console.
3. Install project-specific dependencies, including go, docker, skaffold, and kubectl:

```
wget -O - https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/main/.github/workflows/install-dependencies.sh | bash
```

The instance will restart when the script completes in order to finish the Docker install.

4. SSH back into the VM.

5. Follow the instructions to add a new runner on the [Actions Settings page](https://github.com/GoogleCloudPlatform/microservices-demo/settings/actions) to authenticate the new runner
6. Start GitHub Actions as a background service:
```
sudo ~/actions-runner/svc.sh install ; sudo ~/actions-runner/svc.sh start
```
