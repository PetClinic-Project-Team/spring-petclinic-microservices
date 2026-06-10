module "vpc" {
  source = "./modules/vpc"

  vpc_cidr              = var.vpc_cidr
  public_subnet_1_cidr  = var.public_subnet_1_cidr
  public_subnet_2_cidr  = var.public_subnet_2_cidr
  private_subnet_1_cidr = var.private_subnet_1_cidr
  private_subnet_2_cidr = var.private_subnet_2_cidr
}

module "iam" {
  source = "./modules/iam"

  cluster_name = var.cluster_name
}

module "eks" {
  source = "./modules/eks"

  cluster_name       = var.cluster_name
  cluster_role_arn   = module.iam.cluster_role_arn
  node_role_arn      = module.iam.node_role_arn
  private_subnet_ids = module.vpc.private_subnet_ids
  desired_size       = var.desired_size
  max_size           = var.max_size
  min_size           = var.min_size
}

module "ecr" {
  source = "./modules/ecr"

  repository_names = [
    "petclinic/spring-petclinic-config-server",
    "petclinic/spring-petclinic-discovery-server",
    "petclinic/spring-petclinic-customers-service",
    "petclinic/spring-petclinic-vets-service",
    "petclinic/spring-petclinic-visits-service",
    "petclinic/spring-petclinic-api-gateway"
  ]
}
