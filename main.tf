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
  route_table_id = aws_route_table.private_rt.id
  Name = "Private A"
  source = "./subnet_module"
}
module "private_subnet_B" {
  vpc_id     = module.vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "ap-south-1b"
  route_table_id = aws_route_table.private_rt.id
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
## NAT gateway
#EIP for NAT gw
resource "aws_eip" "nat_gw_eip"{
  vpc = true
  depends_on = [aws_internet_gateway.ig]
} 
# NAT gateway 
resource "aws_nat_gateway" "gw" {
  allocation_id = aws_eip.nat_gw_eip.id
  subnet_id     = module.public_subnet_A.id

  tags = {
    Name = "gw NAT"
  }
}
#route table for private subnet
resource "aws_route_table" "private_rt" {
  vpc_id = module.vpc.id
  tags = {
    "Name" = "private-route-table"
  }
}
##
resource "aws_route" "private_nat_gateway" {
  route_table_id         = "${aws_route_table.private_rt.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_nat_gateway.gw.id}"
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
# Resource ELB
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
  max_size           = 5
  min_size           = 2
  launch_template {
    id      = aws_launch_template.private_lt.id
    version = "$Latest"
  }
  
}

#autoscaling policy
resource "aws_autoscaling_policy" "asg-cpu-policy" {
  name = "asg-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.private_asg.name
  adjustment_type = "ChangeInCapacity"
  scaling_adjustment = "1"
  cooldown = "300"
  policy_type = "SimpleScaling"
}
#Cloud watch alarm
resource "aws_cloudwatch_metric_alarm" "asg-cpu-alarm"{
  alarm_name = "asg-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "30"
  dimensions = {
    "AutoScalingGroupName" = "${aws_autoscaling_group.private_asg.name}"
  }
  actions_enabled = true
  alarm_actions = ["${aws_autoscaling_policy.asg-cpu-policy.arn}"]
}

resource "aws_autoscaling_policy" "asg-cpu-policy-scaledown" {
  name = "asg-cpu-policy-scaledown"
  autoscaling_group_name = "${aws_autoscaling_group.private_asg.name}"
  adjustment_type = "ChangeInCapacity"
  scaling_adjustment = "-1"
  cooldown = "300"
  policy_type = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "asg-cpu-alarm-scaledown" {
  alarm_name = "asg-cpu-alarm-scaledown"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "5"
  dimensions = {
  "AutoScalingGroupName" = "${aws_autoscaling_group.private_asg.name}"
  }
  actions_enabled = true
  alarm_actions = ["${aws_autoscaling_policy.asg-cpu-policy-scaledown.arn}"]
}