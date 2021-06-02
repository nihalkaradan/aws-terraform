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
# create internet gateway
resource "aws_internet_gateway" "ig" {
  vpc_id = module.vpc.id
  tags = {
    "Name" = "ig"
  }
}
# Routing table for public subnet
resource "aws_route_table" "public_rt" {
  vpc_id = module.vpc.id
  tags = {
    "Name" = "public-route-table"
  }
}
#Add ig entry to route table
resource "aws_route" "public_internet_gateway" {
  route_table_id         = "${aws_route_table.public_rt.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.ig.id}"
}
# Two public subnets and two private subnets 
# Two AZs ap-south-1a and ap-south-1b
module "public_subnet_A" {
  vpc_id     = module.vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  route_table_id = aws_route_table.public_rt.id
  Name = "Public A"
  source = "./public_subnet_module"
}
module "public_subnet_B" {
  vpc_id     = module.vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  route_table_id = aws_route_table.public_rt.id
  Name = "Public B"
  source = "./public_subnet_module"
}
module "private_subnet_A" {
  vpc_id     = module.vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "ap-south-1a"
  Name = "Private A"
  source = "./subnet_module"
}
module "private_subnet_B" {
  vpc_id     = module.vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "ap-south-1b"
  Name = "Private B"
  source = "./subnet_module"
}
#public security group
resource "aws_security_group" "public_sg" {
  vpc_id = module.vpc.id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
# EC2 instance in Public subnet
resource "aws_instance" "BastionHost" {
  key_name = "code-mancers"
  ami = "ami-010aff33ed5991201"
  instance_type = "t2.micro"
  availability_zone = "ap-south-1a"
  subnet_id = module.public_subnet_A.id
  security_groups = ["${aws_security_group.public_sg.id}"]
  tags = {
    "Name" = "Public EC2"
  }
}
# Private security group

resource "aws_security_group" "private_sg" {
  vpc_id = module.vpc.id
  ingress {
    cidr_blocks = [
      module.public_subnet_A.cidr_block,
      module.public_subnet_B.cidr_block
    ]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 80
    to_port = 80
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 443
    to_port = 443
    protocol = "tcp"
  }
  egress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 80
    to_port = 80
    protocol = "tcp"
  }
  egress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 443
    to_port = 443
    protocol = "tcp"
  }
}

#launch template for autoscaling group
resource "aws_launch_template" "private_lt" {
  name_prefix   = "private_lt"
  image_id      = "ami-010aff33ed5991201"
  instance_type = "t2.micro"
  key_name = "code-mancers"
  vpc_security_group_ids = [
    aws_security_group.private_sg.id

  ]
  # security_group_names = [aws_security_group.private_sg.id]
  
} 
#load balancer
resource "aws_security_group" "elb_sg" {
  vpc_id = module.vpc.id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 80
    to_port = 80
    protocol = "tcp"
  }
  egress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 80
    to_port = 80
    protocol = "tcp"
  }
}
resource "aws_elb" "private_asg_elb" {
  subnets = [module.public_subnet_A.id,module.public_subnet_B.id]
  internal = true
  name = "private-asg-elb"
  security_groups = [aws_security_group.elb_sg.id]
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  cross_zone_load_balancing   = true
  tags = {
    Name = "private-asg-elb"
  }
}
#autoscaling group and attach loadbalancer
resource "aws_autoscaling_group" "private_asg" {
  # availability_zones = ["ap-south-1a","ap-south-1b"]
  depends_on = [
    aws_launch_template.private_lt

  ]
  load_balancers = [aws_elb.private_asg_elb.id]
  vpc_zone_identifier = [module.private_subnet_A.id,module.private_subnet_B.id]
  desired_capacity   = 2
  max_size           = 2
  min_size           = 2
  launch_template {
    id      = aws_launch_template.private_lt.id
    version = "$Latest"
  }
  
}
