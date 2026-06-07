variable "cluster_name" {
  type        = string
  description = "Used as a name prefix for all VPC resources"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "region" {
  type        = string
  description = "AWS region — used to fetch available AZs"
}
