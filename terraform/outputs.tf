output "cluster_name" {
  description = "EKS cluster name"
  value       = var.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = aws_eks_cluster.eks.endpoint
}

output "eks_admin_role_arn" {
  description = "IAM role ARN that can administer the EKS cluster"
  value       = aws_iam_role.eks_admin.arn
}
