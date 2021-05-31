provider "aws"{
  profile = "nihal-terraform"
  region = "ap-south-1"
}
# VPC creation
module "vpc" {
  cidr_block = "10.0.0.0/16"
  Name = "main"
  source = "./vpc_module"
}
# Two public subnets and two private subnets 
# Two AZ ap-south-1a and ap-south-1b
module "public_subnet_A" {
  vpc_id     = module.vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  Name = "Public A"
  source = "./subnet_module"
}
module "public_subnet_B" {
  vpc_id     = module.vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  Name = "Public B"
  source = "./subnet_module"
}
module "private_subnet_A" {
  vpc_id     = module.vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "ap-south-1a"
  Name = "Public A"
  source = "./subnet_module"
}
module "private_subnet_B" {
  vpc_id     = module.vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "ap-south-1b"
  Name = "Private B"
  source = "./subnet_module"
}
# add internet gateway to public subnets
resource "aws_internet_gateway" "ig" {
  vpc_id = module.vpc.id
}
resource "aws_route" "name" {
  
}

