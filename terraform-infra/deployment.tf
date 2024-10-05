variable "app_name" {
    type = string
    default = "Foo App"
    description = "The Name of the Application. Will Automatically Change EC2 Names on deployment."
}
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
        Name = "${var.app_name} application"
    }
}

resource "aws_instance" "database" {
    ami = data.aws_ami.ubuntu.id
    instance_type = "t2.micro"
    key_name = aws_key_pair.admin.key_name
    security_groups = [aws_security_group.db_access_config.name]
    tags = {
        Name = "${var.app_name} database"
    }
}

resource "aws_key_pair" "admin" {
    key_name = "admin-key-${var.app_name}"
    public_key = file(var.path_to_ssh_public_key)
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

resource "aws_security_group" "db_access_config" {
    name = "db_port_${var.app_name}"
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
    # PostgreSQL out
    ingress {
        from_port   = 0
        to_port     = 5432
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}


output "ini_file" {
    value = "inventory.ini"
}
output "app_public_hostname" {
    value = aws_instance.app.public_dns
}
output "app_public_ip" {
    value = aws_instance.app.public_ip
}
output "db_public_hostname" {
    value = aws_instance.database.public_dns
}

output "db_public_ip" {
    value = aws_instance.database.public_ip
}