variable "vpc_id" {}
variable "cidr_block" {}
variable "availability_zone" {}
variable "Name" {}
variable "route_table_id" {}
resource "aws_subnet" "subnet" {
  vpc_id     = var.vpc_id
  cidr_block = var.cidr_block
  availability_zone = var.availability_zone
  map_public_ip_on_launch = true
  tags = {
    Name = var.Name 
  }
}
resource "aws_route_table_association" "public" {
  subnet_id = aws_subnet.subnet.id
  route_table_id = var.route_table_id
}
output "id" {
  value = aws_subnet.subnet.id
}
output "cidr_block" {
  value = aws_subnet.subnet.cidr_block
}
