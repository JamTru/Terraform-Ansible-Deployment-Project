variable "app_name" {
    type = string
    default = "Foo_App"
}
terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 4.0"
        }
    }
}

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
  owners = ["099720109477"]
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "main"
  }
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public Subnet CIDR values"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

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

variable "azs" {
 type        = list(string)
 description = "Availability Zones"
 default     = ["us-east-1a", "us-east-1b"]
}


resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw"
  }
}

//resource "aws_instance" "app" {
//  ami = data.aws_ami.ubuntu.id
//  instance_type = "t2.micro"
//  key_name = aws_key_pair.admin.key_name
//  security_groups = [aws_security_group.app_access_config.name]
//  subnet_id = aws_subnet.public_subnet_1.id
//  tags = {
//    Name = "${var.app_name} application"
//  }
//}
//
//resource "aws_instance" "app2" {
//  ami = data.aws_ami.ubuntu.id
//  instance_type = "t2.micro"
//  key_name = aws_key_pair.admin.key_name
//  security_groups = [aws_security_group.app_access_config.name]
//  subnet_id = aws_subnet.public_subnet_2.id
//  tags = {
//    Name = "${var.app_name} application"
//  }
//}

resource "aws_instance" "app" {
  count = 2
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.admin.key_name
  //security_groups = [aws_security_group.app_access_config.name]
  vpc_security_group_ids = [aws_security_group.app_access_config.id]
  subnet_id = aws_subnet.public_subnets[count.index].id
  associate_public_ip_address = true
  tags = {
    Name = "${var.app_name} application - ${count.index}"
  }
}

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

resource "aws_route_table_association" "public_subnet" {
  count = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.public_route_table.id

}


//resource "aws_lb" "main" {
//  name = "lb-Foo-App"
//  internal = false
//  load_balancer_type = "application"
//  security_groups = [aws_security_group.app_access_config.name]
//  //subnets = [aws_subnet.public_subnets_1.id, aws_subnet.public_subnets_2.id]
//    subnets = [
//      aws_subnet.public_subnets[0].id,
//      aws_subnet.public_subnets[1].id,
//    ]
//  enable_deletion_protection = false
//}

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

resource "aws_lb_target_group_attachment" "web_server" {
  count = 2
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.app[count.index].id
  port             = 80
}

//resource "aws_lb_target_group_attachment" "app_target_group_attachment" {
//  count = 2
//
//  target_group_arn = "${aws_lb_target_group.main.arn}"
//  target_id        = "${aws_instance.app[count.index].id}"
//}

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
    public_key = file("~/.ssh/github_sdo_key.pub")
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

    # HTTP in
    ingress {
        from_port = 0
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 443
        to_port = 443
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

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
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
        cidr_blocks = ["124.188.72.32/32"]
    }

}


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
