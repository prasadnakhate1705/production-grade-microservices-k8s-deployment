variable "region" {
  type        = string
  description = "AWS region to deploy the EKS cluster"
  default     = "us-east-1"
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
  default     = "MicroservicesDemoCluster-Prasad"
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes version for the EKS cluster. Keep this on a version still in EKS STANDARD support — versions in extended support bill $0.60/hr for the control plane instead of $0.10/hr."
  default     = "1.34"
}

variable "istio_version" {
  type        = string
  description = <<-EOT
    Istio version for all three Helm releases (base, istiod, gateway).

    MUST cover the cluster_version above in Istio's support matrix
    (https://istio.io/latest/docs/releases/supported-releases/):
      Istio 1.30 → Kubernetes 1.32 – 1.36
      Istio 1.29 → Kubernetes 1.31 – 1.35
    Running Istio outside its tested matrix is the most likely cause of a
    cluster that comes up but never forms a mesh (istiod crashlooping, the
    injection webhook silently not firing, or CRDs the API server rejects).
  EOT
  default     = "1.30.3"
}

variable "node_instance_type" {
  type        = string
  description = "EC2 instance type for the system node group"
  default     = "t3.medium"
}

variable "app_instance_types" {
  type        = list(string)
  description = "Instance types for the app node group. Diversified for better Spot availability (all 2 vCPU / 4 GB)."
  default     = ["t3.medium", "t3a.medium"]
}

variable "system_capacity_type" {
  type        = string
  description = "Capacity type for system nodes: ON_DEMAND or SPOT."
  default     = "ON_DEMAND"
}

variable "app_capacity_type" {
  type        = string
  description = "Capacity type for app nodes: ON_DEMAND or SPOT."
  default     = "SPOT"
}

variable "node_desired_size" {
  type        = number
  description = "Desired number of worker nodes"
  default     = 2
}

variable "node_min_size" {
  type        = number
  description = "Minimum number of worker nodes"
  default     = 1
}

variable "node_max_size" {
  type        = number
  description = "Maximum number of worker nodes (for autoscaling)"
  default     = 4
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "system_node_desired_size" {
  type        = number
  description = "Desired number of system nodes (Istio + ArgoCD)"
  default     = 2
}

variable "system_node_min_size" {
  type        = number
  description = "Minimum number of system nodes"
  default     = 2
}

variable "system_node_max_size" {
  type        = number
  description = "Maximum number of system nodes"
  default     = 2
}

variable "github_repo" {
  type        = string
  description = "GitHub repo in owner/name format — e.g. prasadnakhate/microservices-demo. Used to scope the OIDC trust policy so only this repo can assume the AWS deploy role."
}
