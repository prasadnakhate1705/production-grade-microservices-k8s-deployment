terraform {
  # 1.11 is the floor for S3 native state locking (use_lockfile) below.
  required_version = ">= 1.11.0"

  # ─── Remote state ───────────────────────────────────────────────────────────
  # State lives in S3 (shared by your laptop bootstrap AND every CI run).
  # Locking uses S3 native conditional writes (use_lockfile) rather than a
  # DynamoDB table — Terraform writes a .tflock object next to the state and
  # relies on S3's If-None-Match to make the acquire atomic. Requires Terraform
  # >= 1.11; DynamoDB-based locking is deprecated.
  # The bucket must be created ONCE before `terraform init` (see BOOTSTRAP.md).
  # NOTE: S3 bucket names are globally unique — change if this one is taken.
  backend "s3" {
    bucket       = "microservicesdemo-prasad-tfstate"
    key          = "eks/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Kubernetes provider — wired to the EKS cluster via module outputs
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# Helm provider — same auth as kubernetes provider, used to install Istio
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # --region is explicit: without it the CLI falls back to the ambient
      # AWS_REGION / profile region, which silently targets the wrong account's
      # cluster from a laptop configured for a different default region.
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
    }
  }
}
