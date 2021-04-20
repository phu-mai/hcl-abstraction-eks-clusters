# EKS ABSTRACTION LAYER
The EKS abstraction layer is wrapper the multiple functions (module or resource) in order to allowed users to easily to create clusters with a simple inputs

## Terraform versions

Only Terraform 0.12 or newer is supported.

## Usage example:

```
module "eks_cluster_001" {
  source          = "./eks-clusters"
  env_name        = "dev"
  cluster_version = "1.18"
  vpc_id          = "vpc-77777777777777777"
  subnet_ids      = ["subnet-11111111111111168","subnet-22222222222222211","subnet-33333333333333333","subnet-44444444444444444","subnet-55555555555555555","subnet-66666666666666666"]
  account_id      = var.account_id
  cluster_name    = "shared-eks-dev-001"
  workers_additional_policies   = ["EC2EbsCsiDriver"]
  worker_groups_launch_template = [
  {
    name                 = "on-demand-infra_ap-southeast-1a"
    key_name             = "<key_name>"
    instance_type        = "t3a.medium"
    asg_min_size         = 1
    asg_desired_capacity = 1
    asg_max_size         = 1
    availability_zone    = "ap-southeast-1a"
    bootstrap_extra_args    = "--enable-docker-bridge true --use-max-pods false"
    kubelet_extra_args   = "--node-labels=node.kubernetes.io/lifecycle=normal,daemonset=active,"
  }
]
  map_users  = [
  {
    userarn  = "AWSReservedSSO_CXA-DEVOPS_8fe62e3e43fzxyas"
    username = "devops-team"
    groups   = ["system:masters"]
  }
  ]
  tags            = var.tags
}

```
