resource "null_resource" "k8s_destroy_cleanup" {
  triggers = {
    manifest_sha = filesha256("${path.module}/../release/kubernetes-manifests.yaml")
  }

  depends_on = [
    aws_eks_node_group.default,
  ]

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete -f ${path.module}/../release/kubernetes-manifests.yaml --ignore-not-found=true || true"
  }
}
