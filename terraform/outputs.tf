output "cluster_name" {
  description = "EKS cluster name"
  value       = var.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = aws_eks_cluster.eks.endpoint
}
