module "vpc" {
  source       = "./modules/vpc"
  cluster_name = var.cluster_name
  vpc_cidr     = var.vpc_cidr
  region       = var.region
}

module "eks" {
  source             = "./modules/eks"
  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  region             = var.region
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  node_instance_type = var.node_instance_type
  app_instance_types = var.app_instance_types

  # capacity type per group — system on-demand for stability, app on spot for cost
  system_capacity_type = var.system_capacity_type
  app_capacity_type    = var.app_capacity_type

  # app node group — hosts the 11 microservices
  node_desired_size = var.node_desired_size
  node_min_size     = var.node_min_size
  node_max_size     = var.node_max_size

  # system node group — hosts Istio + ArgoCD
  system_node_desired_size = var.system_node_desired_size
  system_node_min_size     = var.system_node_min_size
  system_node_max_size     = var.system_node_max_size
}

module "ecr" {
  source       = "./modules/ecr"
  cluster_name = var.cluster_name
}

module "github_oidc" {
  source       = "./modules/github-oidc"
  github_repo  = var.github_repo
  cluster_name = var.cluster_name
  ecr_registry = module.ecr.registry
}

# Update local kubeconfig after cluster is ready
resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
  }
  depends_on = [module.eks]
}
