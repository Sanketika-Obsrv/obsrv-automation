output "kubernetes_host" {
  value = aws_eks_cluster.eks_master.endpoint
}

output "kubernetes_ca_certificate" {
  value = base64decode(aws_eks_cluster.eks_master.certificate_authority.0.data)
}

output "dataset_api_sa_annotations" {
  value = aws_iam_role.dataset_api_sa_iam_role.arn
}