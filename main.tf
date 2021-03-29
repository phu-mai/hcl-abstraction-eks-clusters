data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  version                = "~> 1.5"
}

provider "kubectl" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  version                = "~> 1.5"
}

module "eks" {
  source                               = "git::git@github.com:cxagroup/infra-terraform-modules//terraform-aws-eks?ref=INFRA-1514-Upgrade_Terraform_to_0.13.5"
  create_eks                           = var.create
  cluster_name                         = var.cluster_name
  subnets                              = var.subnet_ids
  vpc_id                               = var.vpc_id
  cluster_version                      = var.cluster_version
  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  enable_irsa                          = var.enable_irsa
  worker_additional_security_group_ids = local.worker_additional_security_group_ids
  workers_additional_policies          = local.workers_additional_policies
  worker_groups_launch_template        = local.worker_groups_launch_template
  tags                                 = local.eks_tags
  map_users                            = local.map_users
}

data "kubectl_path_documents" "manifests" {
    pattern = "./manifests/*.yaml"
}

resource "kubectl_manifest" "aws_calico" {
    count     = length(data.kubectl_path_documents.manifests.documents)
    yaml_body = element(data.kubectl_path_documents.manifests.documents, count.index)
}
