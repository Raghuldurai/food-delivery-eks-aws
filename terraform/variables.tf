variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.35"
}

variable "instance_type_eks" {
  type = string
}

variable "min_nodes" {
  type = number
}

variable "max_nodes" {
  type = number
}

variable "desired_size" {
  type = number
}

# ── VPC variables ─────────────────────────────────────────────────────────────

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "food-delivery-vpc"
}

variable "vpc_cidr" {
  description = <<-EOT
    CIDR block for the entire VPC.
    10.0.0.0/24 gives 256 IPs — fits 2 private /26 subnets (62 usable each)
    and 2 public /27 subnets (30 usable each) with no waste.
  EOT
  type        = string
  default     = "10.0.0.0/24"
}

variable "azs" {
  description = "Availability zones — minimum 2 required for both EKS and ALB"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "private_subnets" {
  description = <<-EOT
    CIDR blocks for private subnets — EKS worker nodes live here.
    2 x /26 → 62 usable IPs each. t3.medium holds max 17 pods;
    3 nodes total = 51 IPs needed, so 62 per subnet covers it with headroom.
  EOT
  type        = list(string)
  default     = ["10.0.0.0/26", "10.0.0.64/26"]
}

variable "public_subnets" {
  description = <<-EOT
    CIDR blocks for public subnets — NAT Gateway and ALB live here.
    2 x /27 → 30 usable IPs each. AWS hard minimum for ALB is /27;
    going smaller (/28) causes ALB provisioning failures.
  EOT
  type        = list(string)
  default     = ["10.0.0.128/27", "10.0.0.160/27"]
}
