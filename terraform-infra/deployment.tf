# Variable for Naming the EC2 Instances
# Change this value to modify the name of the EC2 instances created by this module.
variable "app_name" {
    type = string
    default = "Foo_App"
    description = "Variable for Naming the EC2 Instances. Change to modify the name output."
}

# Specifies the required provider for the Terraform configuration.
terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 4.0"
        }
    }
}

# Configure the AWS provider with the region
provider "aws" {
    region = "us-east-1"
}

# Retrieves the most recent Ubuntu Server 22.04 HVM AMI
data "aws_ami" "ubuntu" {
    most_recent = true
    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
    }
    filter {
      name = "virtualization-type"
      values = ["hvm"]
    }
  owners = ["099720109477"]
}

# Creates a VPC with the specified CIDR block and enabled DNS support.
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "main"
  }
}

# List of public subnets for the ec2 instances 
variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public Subnet CIDR values"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

#  Creates public subnets within the VPC
# creates 2 subnets for 2 ec2 instaces
# Takes in variables from avaliability zones and cidr blocks
# VPC is defined 
resource "aws_subnet" "public_subnets" {
  count      = length(var.public_subnet_cidrs)
  vpc_id     = aws_vpc.main.id
  cidr_block = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}

# list of availability zones for the EC2 instances 
variable "azs" {
  type        = list(string)
  description = "Availability Zones"
  default     = ["us-east-1a", "us-east-1b"]
}

# Creates an AWS internet gateway resource named "igw"
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw"
  }
}

# Creates two Amazon EC2 instances for the application deployment.
# t2 micro tier
resource "aws_instance" "app" {
  count = 2
  ami = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name = aws_key_pair.admin.key_name
  vpc_security_group_ids = [aws_security_group.app_access_config.id]
  subnet_id = aws_subnet.public_subnets[count.index].id
  associate_public_ip_address = true
  tags = {
    Name = "${var.app_name} application - ${count.index}"
  }
}

# Creates a public route table for the VPC
# Used to route traffic to the right instance 
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "Route-Table"
  }
}

# Associates public subnets with the public route table.
resource "aws_route_table_association" "public_subnet" {
  count = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.public_route_table.id

}

# Creates an Application Load Balancer (ALB) resource in AWS.
resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_access_config.id]
  subnets            = [for subnet in aws_subnet.public_subnets : subnet.id]
  enable_deletion_protection = false
  tags = {
    Environment = "production"
  }
}

# Resource definition for an AWS Application Load Balancer (ALB) target group
# Health check configuration for the target group
resource "aws_lb_target_group" "main" {
  name = "target-group-Foo-App"
  port        = 80
  ip_address_type = "ipv4"
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id = aws_vpc.main.id

  health_check {
    interval = 30
    timeout = 5
    healthy_threshold = 3
    unhealthy_threshold = 2
    path = "/"
  }
}

# This resource attaches multiple EC2 instances to an Application Load Balancer (ALB) target group.
resource "aws_lb_target_group_attachment" "web_server" {
  count = 2
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.app[count.index].id
  port             = 80
}


# Provision a database server on AWS
resource "aws_instance" "database" {
    ami = data.aws_ami.ubuntu.id
    instance_type = "t2.micro"
    key_name = aws_key_pair.admin.key_name
    security_groups = [aws_security_group.db_access_config.name]
    associate_public_ip_address = true
    tags = {
        Name = "${var.app_name} database"
    }
}

# This resource defines an AWS Key Pair
resource "aws_key_pair" "admin" {
    key_name = "admin-key-${var.app_name}"
    public_key = file("./local_pub_key.pub")
}

resource "aws_security_group" "app_access_config" {
    name = "vm_inbound_${var.app_name}"
    vpc_id = aws_vpc.main.id

    # SSH
    ingress {
        from_port = 0
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # PostgreSQL in
    ingress {
        from_port   = 0
          to_port     = 5432
          protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # HTTP in
    ingress {
        from_port = 0
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # HTTPS out
    egress {
        from_port = 0
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    # PostgreSQL Out
    egress {
        from_port   = 5432
        to_port     = 5432
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# create security group for the cloud along with LB routing 
resource "aws_security_group" "db_access_config" {
    name = "db_port_${var.app_name}"
    # SSH
    # Allow SSH access from anywhere (0.0.0.0/0) on port 22
    ingress {
        from_port = 0
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    # PostgreSQL in
    # Allow inbound traffic for PostgreSQL on port 5432 from anywhere
    ingress {
        from_port   = 0
        to_port     = 5432
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # HTTP in
    # Allow inbound HTTP traffic on port 80 from anywhere
    ingress {
        from_port = 0
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # HTTPS out
    # Allow outbound HTTPS traffic on port 443 to anywhere
    egress {
        from_port = 0
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    # PostgreSQL out
    # Allow outbound PostgreSQL traffic on port 5432 to anywhere
    ingress {
        from_port   = 0
        to_port     = 5432
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

}

#create a bucket which can store the state file for terraform
terraform {
  backend "s3" {
    # bucket         = "terraform-bucket1234567"  # Abel Bucket
    bucket = "terraform-state-j" # Jamie Bucket
    key = "global/s3/terraform.tfstate"
    region = "us-east-1"
  }
}


# Outputs for Terraform configuration
output "ini_file" {
    value = "inventory.ini"
}
output "app_public_hostname" {
  value = aws_instance.app[*].public_dns
}
output "app_public_ip" {
    value = aws_instance.app[*].public_ip
}
output "db_public_hostname" {
    value = aws_instance.database.public_dns
}

output "db_public_ip" {
    value = aws_instance.database.public_ip
}
