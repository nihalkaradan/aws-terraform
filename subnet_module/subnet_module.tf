variable "vpc_id" {}
variable "cidr_block" {}
variable "availability_zone" {}
variable "Name" {}
resource "aws_subnet" "subnet" {
  vpc_id     = var.vpc_id
  cidr_block = var.cidr_block
  availability_zone = var.availability_zone
  tags = {
    Name = var.Name 
  }
}