variable "KARPENTER_NAMESPACE" {
  type = string
  default = "karpenter"
}

variable "CLUSTER_NAME" {
    type = string
    default = "DemoCluster"
}

variable "AWS_REGION" {
  type = string
  default = "us-east-1"
}

variable "AWS_ACCOUNT_ID" {
    type = string
    default = "456125790758"
}
variable "AWS_AMI_ID" {
    type = string
    default = "ami-999f24d6ec63084c5"
}

variable "KARPENTER_VERSION" {
  type = string
  default = "1.0.7"
}
