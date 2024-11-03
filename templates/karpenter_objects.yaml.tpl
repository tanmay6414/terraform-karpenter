apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: general-purpose
  namespace: "${KARPENTER_NAMESPACE}"
  annotations:
    kubernetes.io/description: "General purpose NodePool for generic workloads"
spec:
  template:
    metadata:
      labels:
        tier: cluster-level
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        # - key: "karpenter.k8s.aws/instance-family"
        #   operator: In
        #   values: ["t3"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
        - key: "topology.kubernetes.io/zone"
          operator: In
          values: ["eu-west-1b"]
        # - key: "karpenter.k8s.aws/instance-cpu"
        #   operator: In
        #   values: ["2"]
      taints:
      - key: tier
        value: frontend
        effect: NoSchedule
      nodeClassRef:
        apiVersion: karpenter.k8s.aws/v1beta1
        kind: EC2NodeClass
        name: default
---
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: default
  namespace: "${KARPENTER_NAMESPACE}"
  annotations:
    kubernetes.io/description: "General purpose EC2NodeClass for running Amazon Linux 2 nodes"
spec:
  amiFamily: AL2
  amiSelectorTerms:
    - id: "${AWS_AMI_ID}"
  role: "${KarpenterNodeRole}"
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}"
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}"
