# Create the VPC

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "terraform-boto3-vpc"
  }
}


# Create a subnet inside the VPC

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "terraform-boto3-public-subnet"
  }
}


# Create the Internet Gateway

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform-boto3-igw"
  }
}


# Create a route table for the public subnet

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Send internet traffic to the Internet Gateway

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "terraform-boto3-public-route-table"
  }
}


# Connect the public subnet to the route table

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}


# Create the security group

resource "aws_security_group" "ec2" {
  name        = "terraform-boto3-ec2-sg"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = aws_vpc.main.id

  # Allow SSH

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # Allow HTTP

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow the EC2 instance to send traffic out.

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-boto3-ec2-sg"
  }
}


# Get the latest Amazon Linux 2023 AMI

data "aws_ssm_parameter" "amazon_linux" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}


# Create the EC2 instance

resource "aws_instance" "web" {
  ami           = data.aws_ssm_parameter.amazon_linux.value
  instance_type = var.instance_type

  subnet_id = aws_subnet.public.id

  vpc_security_group_ids = [
    aws_security_group.ec2.id
  ]

  # Only send a key pair to EC2 when one was provided.

  key_name = var.key_name != "" ? var.key_name : null

  iam_instance_profile = aws_iam_instance_profile.ec2.name

  user_data = <<-EOF
              #!/bin/bash

              # Update installed packages

              dnf update -y

              # Install a simple web server

              dnf install -y httpd

              # Start Apache

              systemctl enable httpd
              systemctl start httpd

              # Create a simple page

              echo "<h1>Hello from Terraform and EC2</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = var.instance_name
  }
}


# Create the Elastic IP

resource "aws_eip" "web" {
  domain = "vpc"

  tags = {
    Name = "terraform-boto3-eip"
  }
}


# Attach the Elastic IP to the EC2 instance

resource "aws_eip_association" "web" {
  instance_id   = aws_instance.web.id
  allocation_id = aws_eip.web.id
}
