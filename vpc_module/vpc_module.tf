variable "cidr_block" {}
variable "Name" {}
resource "aws_vpc" "main" {
    cidr_block = var.cidr_block
#   cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    # Name = "main"
    Name = var.Name
  }
}
output "id" {
  value = aws_vpc.main.id
}