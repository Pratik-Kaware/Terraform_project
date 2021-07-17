provider "aws" {
  access_key = "AKIAZ32FMD4J6TF56D3S"
  secret_key = "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"
  region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    "key" = "Production"
  }
}

# Create a internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
}

# custom route table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "TF-Route-Table"
  }
}

# Create a subnet 
resource "aws_subnet" "subnet-1" {
    vpc_id = aws_vpc.prod-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a" 
    tags = {
        Name = "prod-subnet"
    }

}

# Associate subnet to route table 
# Using TF aws route table association

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# Create a security group

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "For HTTPS"
    # allowing inbound traffic from 443 to 443
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    # Anyone can access it
    cidr_blocks      = ["0.0.0.0/0"] 
    
  }
  ingress {
    description      = "For SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    # Anyone can access it
    cidr_blocks      = ["0.0.0.0/0"] 
    
  }
  ingress {
    description      = "For HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    # Anyone can access it
    cidr_blocks      = ["0.0.0.0/0"] 
  }

  egress {
    from_port        = 0
    to_port          = 0
    # -1 --- Any Protocol
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# Network Interface
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

# Assign an elastic IP to Network Interface
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  # eip is explicitly dependent on IGW
  depends_on = [aws_internet_gateway.gw]
}

# Shows The Public ipv4 after terraform apply
output "server_public_ip" {
  value = aws_eip.one.public_ip
}

# Create a ubuntu server and install/enable apache

resource "aws_instance" "web-server-instance" {
  ami =  "ami-09e67e426f25ce0d7"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "TF-access-key"
  
  network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.web-server-nic.id
  }
  tags = {
    "Name" = "TF-Web-server"
  }
  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2
                sudo systemctl start apache2
                sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                EOF 
}
# 
output "Server-private-ip" {
    value = aws_instance.web-server-instance.private_ip
}
output "Server-ID" {
  value = aws_instance.web-server-instance.id
}

