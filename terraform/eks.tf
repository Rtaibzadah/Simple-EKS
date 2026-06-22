resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
  tags = merge(local.tags, { Name = "${var.cluster_name}-cluster-role" })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "eks_nodes" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = merge(local.tags, { Name = "${var.cluster_name}-node-role" })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_ecr_read_only" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_security_group" "eks_cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "EKS cluster security group"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.tags, { Name = "${var.cluster_name}-cluster-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "cluster_from_nodes" {
  security_group_id            = aws_security_group.eks_cluster.id
  referenced_security_group_id = aws_security_group.eks_nodes.id
  from_port                    = 443
  ip_protocol                  = "tcp"
  to_port                      = 443
  description                  = "Allow TLS from worker nodes to cluster API"
}

resource "aws_vpc_security_group_egress_rule" "cluster_egress_all" {
  security_group_id = aws_security_group.eks_cluster.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic"
}

resource "aws_security_group" "eks_nodes" {
  name        = "${var.cluster_name}-node-sg"
  description = "EKS node security group"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.tags, {
    Name                                        = "${var.cluster_name}-node-sg"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })
}

resource "aws_vpc_security_group_ingress_rule" "nodes_ingress_self" {
  security_group_id            = aws_security_group.eks_nodes.id
  referenced_security_group_id = aws_security_group.eks_nodes.id
  from_port                    = 0
  ip_protocol                  = "tcp"
  to_port                      = 65535
  description                  = "Allow node to node communication"
}

resource "aws_vpc_security_group_ingress_rule" "nodes_ingress_cluster" {
  security_group_id            = aws_security_group.eks_nodes.id
  referenced_security_group_id = aws_security_group.eks_cluster.id
  from_port                    = 0
  ip_protocol                  = "tcp"
  to_port                      = 65535
  description                  = "Allow control plane to communicate with nodes"
}

resource "aws_vpc_security_group_egress_rule" "nodes_egress_all" {
  security_group_id = aws_security_group.eks_nodes.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic"
}

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  access_config {
    authentication_mode = "API"
  }

  vpc_config {
    security_group_ids = [aws_security_group.eks_cluster.id]
    subnet_ids = concat(
      aws_subnet.public[*].id,
      aws_subnet.private[*].id,
    )
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]

  tags = merge(local.tags, { Name = var.cluster_name })
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.latest_version
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_read_only,
  ]

  tags = merge(local.tags, { Name = "${var.cluster_name}-nodes" })
}

resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = "arn:aws:iam::761639968218:user/terraform-users"
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = "arn:aws:iam::761639968218:user/terraform-users"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

resource "aws_iam_policy" "external_dns" {
  name = "${var.cluster_name}-external-dns"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = "arn:aws:route53:::hostedzone/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.tags, { Name = "${var.cluster_name}-external-dns" })
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = aws_iam_policy.external_dns.arn
}

resource "aws_launch_template" "eks_nodes" {
  name_prefix = "${var.cluster_name}-nodes-"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 20
      volume_type = "gp3"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = merge(local.tags, { Name = "${var.cluster_name}-node-lt" })
}