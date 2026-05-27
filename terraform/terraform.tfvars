aws_region         = "ap-south-1"
cluster_name       = "food-delivery-cluster"
kubernetes_version = "1.35"
instance_type_eks  = "t3.medium"
min_nodes          = 2
max_nodes          = 3
desired_size       = 2

# VPC — all defaults in variables.tf are already tuned for this project,
# so only override here if you want to change something.
vpc_name = "food-delivery-vpc"
