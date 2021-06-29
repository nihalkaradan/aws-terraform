# AWS - Terraform
Create below setup using Hashicorp Terraform:
1. One VPC with name 'main'
2. Two Availability Zones
3. Two Public Subnets and Two Private Subnets
4. One EC2 instance in Public subnet (Bastion Server)
5. One Autoscaling group of 2 servers in Private subnet
6. EC2 in public subnet should be accessible by anybody outside via SSH
7. EC2 in private subnet should be accessible only by EC2 instance in public subnet or any instances in public subnet via SSH
8. Create an load balancer and attach the autoscaling group as target group for requests via port 80
