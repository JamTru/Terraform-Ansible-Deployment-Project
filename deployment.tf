terraform {
  required_providers {
    source = "hashicorp/aws"
    version = "~> 4.0"
  }
}

provider "aws" {
  region = "us-east-1"
}
data "aws_ami" "ubuntu" {
    most_recent = true
    filter {
      name = "name"
      values = [ "buntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" ]
    }
    filter {
      name = "virtualization-type"
      values = [ "hvm" ]
    }
    owners = ["99720109477"]
}

resource "aws_instance" "foo-app" {
    ami = data.aws_ami.ubuntu
    instance_type = "t2.micro"
    tags = {
        Name = "foo app"
    }
}