variable "app_name" {}
variable "my_ip_address" {}
terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 4.0"
        }
    }
}

# Configure the AWS Provider
provider "aws" {
    region = "us-east-1"
}

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
  owners = ["099720109477"] # Canonical
}
resource "aws_instance" "app" {
    ami = data.aws_ami.ubuntu.id
    instance_type = "t2.micro"

    key_name = aws_key_pair.admin.key_name
    security_groups = [aws_security_group.app_access_config.name]

    tags = {
        Name = "${var.app_name} server"
    }
}

resource "aws_instance" "database" {
    ami = data.aws_ami.ubuntu.id
    instance_type = "t2.micro"
    key_name = aws_key_pair.admin.key_name
    security_groups = [aws_security_group.db_access_config.name]
    tags = {
        Name = "${var.app_name} server"
    }
}

resource "aws_key_pair" "admin" {
    key_name = "admin-key-${var.app_name}"
    public_key = file("/root/.ssh/github_sdo_key.pub")
}

resource "aws_security_group" "app_access_config" {
    name = "vm_inbound_${var.app_name}"

    # SSH
    ingress {
        from_port = 0
        to_port = 22
        protocol = "tcp"
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
}

resource "aws_security_group" "db_access_config" {
    name = "db_port_${var.app_name}"
      # PostgreSQL in
    ingress {
        from_port   = 0
        to_port     = 5432
        protocol    = "tcp"
        cidr_blocks = ["${var.my_ip_address}/32"]
    }

}


output "vm_public_hostname" {
    value = {
        public_hostname: [aws_instance.app.public_dns, aws_instance.database.public_dns],
        public_ip_address: [aws_instance.app.public_ip, aws_instance.database.public_ip]
    }
}