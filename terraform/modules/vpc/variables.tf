variable "vpc_name" {
  description = "Name tag for the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "List of availability zones"
  type        = list(string)
}

variable "private_subnets" {
  description = "CIDR blocks for private subnets (one per AZ) — EKS worker nodes live here"
  type        = list(string)
}

variable "public_subnets" {
  description = "CIDR blocks for public subnets — NAT Gateway and ALB live here"
  type        = list(string)
}

variable "cluster_name" {
  description = "EKS cluster name — used to tag subnets for discovery"
  type        = string
}
