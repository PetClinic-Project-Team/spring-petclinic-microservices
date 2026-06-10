resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn

  version = "1.31"

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  tags = {
    Name        = "petclinic-cluster"
    Environment = "dev"
    Project     = "spring-petclinic"
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "petclinic-workers"
  node_role_arn   = var.node_role_arn

  subnet_ids = var.private_subnet_ids

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size

  }

  disk_size = 20

  instance_types = ["t3.medium"]

  capacity_type = "ON_DEMAND"

  depends_on = [
    aws_eks_cluster.main
  ]

  tags = {
    Name        = "petclinic-workers"
    Environment = "dev"
    Project     = "spring-petclinic"
  }
}
