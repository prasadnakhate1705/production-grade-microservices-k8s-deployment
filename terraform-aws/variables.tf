variable "region" {
  type        = string
  description = "AWS region to deploy the EKS cluster"
  default     = "us-east-1"
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
  default     = "online-boutique"
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes version for the EKS cluster"
  default     = "1.32"
}

variable "node_instance_type" {
  type        = string
  description = "EC2 instance type for EKS worker nodes"
  default     = "t3.medium"
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

variable "namespace" {
  type        = string
  description = "Kubernetes namespace to deploy Online Boutique into"
  default     = "default"
}

variable "github_repo" {
  type        = string
  description = "GitHub repo in owner/name format — e.g. prasadnakhate/microservices-demo. Used to scope the OIDC trust policy so only this repo can assume the AWS deploy role."
}
