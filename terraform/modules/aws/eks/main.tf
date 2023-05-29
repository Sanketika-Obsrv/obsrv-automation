locals {
  common_tags = {
    Environment   = "${var.env}"
    BuildingBlock = "${var.building_block}"
  }
    kubeconfig = <<KUBECONFIG
      apiVersion: v1
      clusters:
      - cluster:
          certificate-authority-data: ${aws_eks_cluster.eks_master.certificate_authority.0.data}
          server: ${aws_eks_cluster.eks_master.endpoint}
        name: ${aws_eks_cluster.eks_master.arn}
      contexts:
      - context:
          cluster: ${aws_eks_cluster.eks_master.arn}
          user: ${aws_eks_cluster.eks_master.arn}
        name: ${aws_eks_cluster.eks_master.arn}
      current-context: ${aws_eks_cluster.eks_master.arn}
      kind: Config
      preferences: {}
      users:
      - name: ${aws_eks_cluster.eks_master.arn}
        user:
          exec:
            apiVersion: client.authentication.k8s.io/v1beta1
            command: aws
            args:
              - --region
              - "${var.region}"
              - eks
              - get-token
              - --cluster-name
              - "${var.building_block}-${var.env}-eks"
    KUBECONFIG
}

resource "aws_iam_role" "eks_master_role" {
  name               = "${var.building_block}-${var.env}-${var.eks_master_role}"
  assume_role_policy = <<POLICY
  {
    "Version": "2012-10-17",
    "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
      "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
    ]
  }
  POLICY
  tags = merge(
    {
    Name = "${var.building_block}-${var.env}-eks-master-policy"
    },
    local.common_tags,
    var.additional_tags)
}

resource "aws_iam_role" "eks_nodes_role" {
  name        = "${var.building_block}-${var.env}-${var.eks_nodes_role}"
  assume_role_policy = jsonencode({
   Version    = "2012-10-17"
   Statement  = [{
    Effect    = "Allow"
    Principal = {
     Service = "ec2.amazonaws.com"
    }
    Action = "sts:AssumeRole"
   }]
  })
  tags = merge(
    {
    Name = "${var.building_block}-${var.env}-eks-nodes-policy"
    },
    local.common_tags,
    var.additional_tags)
}

resource "aws_iam_role_policy_attachment" "eks_master_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_master_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_policy_attachment" {
  for_each = toset([
  "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
  "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
  "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
  ])
  policy_arn = each.value
  role       = aws_iam_role.eks_nodes_role.name
}

resource "aws_eks_cluster" "eks_master" {
  name     = "${var.building_block}-${var.env}-eks"
  role_arn = aws_iam_role.eks_master_role.arn
  version  = var.eks_version

  vpc_config {
   subnet_ids = var.eks_master_subnet_ids
  }

  tags = merge(
    {
    Name = "${var.building_block}-${var.env}-eks"
    },
    local.common_tags,
    var.additional_tags)

  depends_on = [
  aws_iam_role_policy_attachment.eks_master_policy_attachment
  ]
}

resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.eks_master.name
  node_group_name = var.eks_node_group_name
  node_role_arn   = aws_iam_role.eks_nodes_role.arn
  subnet_ids      = var.eks_nodes_subnet_ids
  ami_type        = var.eks_node_group_ami_type
  instance_types  = var.eks_node_group_instance_type
  capacity_type   = var.eks_node_group_capacity_type
  disk_size       = var.eks_node_disk_size

  tags = merge(
    {
    Name = "${var.building_block}-${var.env}-nodegroup-${var.eks_node_group_capacity_type}"
    },
    local.common_tags,
    var.additional_tags)

  scaling_config {
    desired_size = var.eks_node_group_scaling_config["desired_size"]
    max_size     = var.eks_node_group_scaling_config["max_size"]
    min_size     = var.eks_node_group_scaling_config["min_size"]
  }

  depends_on = [
  aws_iam_role_policy_attachment.eks_node_policy_attachment
  ]
}

resource "aws_eks_addon" "addons" {
  for_each           = { for addon in var.eks_addons : addon.name => addon }
  cluster_name       = aws_eks_cluster.eks_master.id
  addon_name         = each.value.name
  addon_version      = each.value.version
  resolve_conflicts  = "OVERWRITE"
}

data "tls_certificate" "cluster_tls_cert" {
  url = aws_eks_cluster.eks_master.identity.0.oidc.0.issuer
}

resource "aws_iam_openid_connect_provider" "eks_openid" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = concat([data.tls_certificate.cluster_tls_cert.certificates.0.sha1_fingerprint], var.oidc_thumbprint_list)
  url             = aws_eks_cluster.eks_master.identity.0.oidc.0.issuer
}

resource "aws_iam_role" "dataset_api_sa_iam_role" {
  name                = "${var.env}-${var.dataset_api_sa_iam_role_name}"
  assume_role_policy  = templatefile("${path.module}/oidc_assume_role_policy.json.tfpl", { OIDC_ARN = aws_iam_openid_connect_provider.eks_openid.arn, OIDC_URL = replace(aws_iam_openid_connect_provider.eks_openid.url, "https://", ""), NAMESPACE = "${var.dataset_api_namespace}", SA_NAME = "${var.dataset_api_namespace}-sa" })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonS3FullAccess"]
  depends_on          = [aws_iam_openid_connect_provider.eks_openid]
  tags = merge(
    {
    Name = "${var.env}-${var.dataset_api_sa_iam_role_name}"
    },
    local.common_tags,
    var.additional_tags)
}

resource "aws_iam_role" "flink_sa_iam_role" {
  name                = "${var.env}-${var.flink_sa_iam_role_name}"
  assume_role_policy  = templatefile("${path.module}/oidc_assume_role_policy.json.tfpl", { OIDC_ARN = aws_iam_openid_connect_provider.eks_openid.arn, OIDC_URL = replace(aws_iam_openid_connect_provider.eks_openid.url, "https://", ""), NAMESPACE = "${var.flink_namespace}", SA_NAME = "${var.flink_namespace}-sa" })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonS3FullAccess"]
  depends_on          = [aws_iam_openid_connect_provider.eks_openid]
  tags = merge(
    {
    Name = "${var.env}-${var.flink_sa_iam_role_name}"
    },
    local.common_tags,
    var.additional_tags)
}

resource "aws_iam_role" "druid_raw_sa_iam_role" {
  name                = "${var.env}-${var.druid_raw_sa_iam_role_name}"
  assume_role_policy  = templatefile("${path.module}/oidc_assume_role_policy.json.tfpl", { OIDC_ARN = aws_iam_openid_connect_provider.eks_openid.arn, OIDC_URL = replace(aws_iam_openid_connect_provider.eks_openid.url, "https://", ""), NAMESPACE = "${var.druid_raw_namespace}", SA_NAME = "${var.druid_raw_namespace}-sa" })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonS3FullAccess"]
  depends_on          = [aws_iam_openid_connect_provider.eks_openid]
  tags = merge(
    {
    Name = "${var.env}-${var.druid_raw_sa_iam_role_name}"
    },
    local.common_tags,
    var.additional_tags)
}

resource "aws_iam_role" "secor_sa_iam_role" {
  name                = "${var.env}-${var.secor_sa_iam_role_name}"
  assume_role_policy  = templatefile("${path.module}/oidc_assume_role_policy.json.tfpl", { OIDC_ARN = aws_iam_openid_connect_provider.eks_openid.arn, OIDC_URL = replace(aws_iam_openid_connect_provider.eks_openid.url, "https://", ""), NAMESPACE = "${var.secor_namespace}", SA_NAME = "${var.secor_namespace}-sa" })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonS3FullAccess"]
  depends_on          = [aws_iam_openid_connect_provider.eks_openid]
  tags = merge(
    {
    Name = "${var.env}-${var.secor_sa_iam_role_name}"
    },
    local.common_tags,
    var.additional_tags)
}

resource "local_file" "kubeconfig" {
  content  = local.kubeconfig
  filename = "${var.building_block}-${var.env}-kubeconfig.yaml"
}