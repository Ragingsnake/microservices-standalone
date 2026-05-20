/*
  Terraform configuration has been split into multiple files for clarity:

  - versions.tf     : Terraform block and backend
  - providers.tf    : provider configuration
  - variables.tf    : input variables and defaults
  - networking.tf   : VPC, subnets, IGW, route tables
  - iam.tf          : IAM roles and policy attachments
  - eks.tf          : EKS cluster
  - node_group.tf   : Managed node group
  - null_resource.tf: destroy-time cleanup hook
  - outputs.tf      : useful outputs

  All resource names are preserved so the existing Terraform state in your S3
  backend remains valid. Run `terraform init` and `terraform plan` as usual.
*/

