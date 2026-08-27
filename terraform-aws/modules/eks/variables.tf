variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes version"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID — passed in from the vpc module output"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs — nodes are placed here"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs — passed to EKS vpc_config"
}

variable "node_instance_type" {
  type        = string
  description = "EC2 instance type for the system node group"
}

variable "app_instance_types" {
  type        = list(string)
  description = "Instance types for the app node group. A diversified list improves Spot capacity availability (all same 2 vCPU / 4 GB size)."
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

variable "coredns_addon_version" {
  type        = string
  description = "CoreDNS EKS addon version. Leave null to let EKS pick the default for the cluster version."
  default     = null
}

variable "vpc_cni_addon_version" {
  type        = string
  description = "VPC CNI EKS addon version. Leave null to let EKS pick the default for the cluster version (NetworkPolicy support needs >= v1.14)."
  default     = null
}

variable "node_desired_size" {
  type        = number
  description = "Desired number of app worker nodes"
}

variable "node_min_size" {
  type        = number
  description = "Minimum number of app worker nodes"
}

variable "node_max_size" {
  type        = number
  description = "Maximum number of app worker nodes"
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
