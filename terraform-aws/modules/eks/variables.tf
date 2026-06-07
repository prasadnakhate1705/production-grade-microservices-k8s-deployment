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
  description = "EC2 instance type for worker nodes"
}

variable "node_desired_size" {
  type        = number
  description = "Desired number of worker nodes"
}

variable "node_min_size" {
  type        = number
  description = "Minimum number of worker nodes"
}

variable "node_max_size" {
  type        = number
  description = "Maximum number of worker nodes"
}
