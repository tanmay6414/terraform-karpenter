data "aws_eks_cluster" "cluster" {
  name = var.CLUSTER_NAME
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.CLUSTER_NAME
}

resource "aws_iam_role" "KarpenterNodeRole" {
  name = "KarpenterNodeRole-${var.CLUSTER_NAME}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    cluster = var.CLUSTER_NAME
  }
}
resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.KarpenterNodeRole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.KarpenterNodeRole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.KarpenterNodeRole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore" {
  role       = aws_iam_role.KarpenterNodeRole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy" "KarpenterControllerRole" {
  name        = "KarpenterControllerRole"
  description = "IAM policy for Karpenter to manage EC2 instances and IAM roles"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "Karpenter"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ec2:DescribeImages",
          "ec2:RunInstances",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DeleteLaunchTemplate",
          "ec2:CreateTags",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:DescribeSpotPriceHistory",
          "pricing:GetProducts"
        ]
        Resource = "*"
      },
      {
        Sid = "ConditionalEC2Termination"
        Effect = "Allow"
        Action = "ec2:TerminateInstances"
        Resource = "*"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      {
        Sid = "PassNodeIAMRole"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = "arn:aws:iam::${var.AWS_ACCOUNT_ID}:role/KarpenterNodeRole-${var.CLUSTER_NAME}"
      },
      {
        Sid = "EKSClusterEndpointLookup"
        Effect = "Allow"
        Action = "eks:DescribeCluster"
        Resource = "arn:aws:eks:${var.AWS_REGION}:${var.AWS_ACCOUNT_ID}:cluster/${var.CLUSTER_NAME}"
      },
      {
        Sid = "AllowScopedInstanceProfileCreationActions"
        Effect = "Allow"
        Action = ["iam:CreateInstanceProfile"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${var.CLUSTER_NAME}" = "owned"
            "aws:RequestTag/topology.kubernetes.io/region" = "${var.AWS_REGION}"
          }
          StringLike = {
            "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass" = "*"
          }
        }
      },
      {
        Sid = "AllowScopedInstanceProfileTagActions"
        Effect = "Allow"
        Action = ["iam:TagInstanceProfile"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.CLUSTER_NAME}" = "owned"
            "aws:ResourceTag/topology.kubernetes.io/region" = "${var.AWS_REGION}"
            "aws:RequestTag/kubernetes.io/cluster/${var.CLUSTER_NAME}" = "owned"
            "aws:RequestTag/topology.kubernetes.io/region" = "${var.AWS_REGION}"
          }
          StringLike = {
            "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" = "*"
            "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass" = "*"
          }
        }
      },
      {
        Sid = "AllowScopedInstanceProfileActions"
        Effect = "Allow"
        Action = [
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.CLUSTER_NAME}" = "owned"
            "aws:ResourceTag/topology.kubernetes.io/region" = "${var.AWS_REGION}"
          }
          StringLike = {
            "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" = "*"
          }
        }
      },
      {
        Sid = "AllowInstanceProfileReadActions"
        Effect = "Allow"
        Action = "iam:GetInstanceProfile"
        Resource = "*"
      }
    ]
  })
}


resource "aws_iam_role" "KarpenterControllerRole" {
  name               = "KarpenterControllerRole-${var.CLUSTER_NAME}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${var.AWS_ACCOUNT_ID}:oidc-provider/${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:${var.KARPENTER_NAMESPACE}:karpenter"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_policy_attachment" {
  role       = aws_iam_role.KarpenterControllerRole.name
  policy_arn = aws_iam_policy.KarpenterControllerRole.arn
}

resource "aws_iam_role_policy_attachment" "AWSBudgetsReadOnlyAccess" {
  role       = aws_iam_role.KarpenterControllerRole.name
  policy_arn = "arn:aws:iam::aws:policy/AWSBudgetsReadOnlyAccess"
}


resource "aws_ec2_tag" "karpenter_subnet_tag" {
  for_each    = toset(data.aws_eks_cluster.cluster.vpc_config[0].subnet_ids)
  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = var.CLUSTER_NAME
} 

resource "aws_ec2_tag" "karpenter_sg_tag" {
  for_each    = toset(data.aws_eks_cluster.cluster.vpc_config[0].security_group_ids)
  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = var.CLUSTER_NAME
} 

resource "aws_eks_access_entry" "KarpenterNodeRole" {
  cluster_name      = var.CLUSTER_NAME
  principal_arn     = aws_iam_role.KarpenterNodeRole.arn
  type              = "EC2_LINUX"
}

resource "aws_iam_service_linked_role" "spot_service_role" {
  aws_service_name = "spot.amazonaws.com"

  lifecycle {
    ignore_changes = [
      aws_service_name,
    ]
  }
}

resource "helm_release" "karpenter" {
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter/karpenter"
  chart      = "karpenter"
  version    = var.KARPENTER_VERSION

  set {
    name  = "settings.clusterName"
    value = var.CLUSTER_NAME
  }

  set {
    name  = "serviceAccount.annotations.eks.amazonaws.com/role-arn"
    value = aws_iam_role.KarpenterControllerRole.arn
  }

  set {
    name  = "controller.resources.requests.cpu"
    value = "1"
  }
  set {
    name  = "controller.resources.requests.memory"
    value = "1Gi"
  }
}



data "kubectl_path_documents" "karpenter_objects" {
  pattern = "./templates/karpenter_objects.yaml.tpl"
  vars = {
    KarpenterNodeRole = "test" #aws_iam_role.KarpenterNodeRole.name
    CLUSTER_NAME = var.CLUSTER_NAME
    AWS_AMI_ID = var.AWS_AMI_ID
    KARPENTER_NAMESPACE = var.KARPENTER_NAMESPACE
  }
}

resource "kubectl_manifest" "karpenter_objects" {
  count     = length(data.kubectl_path_documents.karpenter_objects.documents)
  yaml_body = element(data.kubectl_path_documents.karpenter_objects.documents, count.index)
}
