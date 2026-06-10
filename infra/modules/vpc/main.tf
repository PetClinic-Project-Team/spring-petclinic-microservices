# Terraform configuration for AWS infrastructure of the Spring Pet Clinic application

data "aws_availability_zones" "available" {
  state = "available"
}

# Create a VPC for the Pet Clinic application
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "petclinic-vpc"
  }
}

# Create first public subnet in the VPC
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_1_cidr
  map_public_ip_on_launch = true

 availability_zone = data.aws_availability_zones.available.names[0]

 tags = {
   Name = "petclinic-public-1"
    "kubernetes.io/role/elb" = "1"
     "kubernetes.io/cluster/petclinic-cluster" = "shared"
}
  }


# Create second public subnet in a different availability zone
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr
  map_public_ip_on_launch = true

  availability_zone = data.aws_availability_zones.available.names[1]

 tags = {
  Name = "petclinic-public-2"
  "kubernetes.io/role/elb" = "1"
   "kubernetes.io/cluster/petclinic-cluster" = "shared"
}
}

# Create first private subnet in the VPC
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
   Name = "petclinic-private-1"
    "kubernetes.io/role/internal-elb" = "1"
     "kubernetes.io/cluster/petclinic-cluster" = "shared"
}
}

# Create second private subnet in a different availability zone
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "petclinic-private-2"
    "kubernetes.io/role/internal-elb" = "1"
     "kubernetes.io/cluster/petclinic-cluster" = "shared"
  }
}
  
  # Create an Internet Gateway for the VPC
  resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

}

# Allocate an Elastic IP for the NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# Create a NAT Gateway in the first public subnet
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_1.id

  depends_on = [
    aws_internet_gateway.igw
  ]

  tags = {
  Name = "petclinic-nat"
}
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
  Name = "petclinic-public-rt"
}
}

# Route for public subnets to access the internet
resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate public route table with first public subnet
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

# Associate public route table with second public subnet
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
    tags = {
  Name = "petclinic-private-rt"
}
}

# Route for private subnets to access the internet via NAT Gateway
resource "aws_route" "private_nat_access" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

# Associate private route table with first private subnet
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

# Associate private route table with second private subnet
resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

