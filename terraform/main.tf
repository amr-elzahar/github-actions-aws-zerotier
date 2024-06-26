provider "aws" {
  region     = "us-east-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_access_key
}

resource "aws_vpc" "gihub-actions-aws_vpc" {
  cidr_block = "10.90.0.0/16"

  tags = {
    Name = "GitHub Actions VPC"
  }
}


resource "aws_subnet" "public-subnet" {
  vpc_id            = aws_vpc.gihub-actions-aws_vpc.id
  cidr_block        = "10.90.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Public Subnet"
  }
}



resource "aws_subnet" "private-subnet01" {
  vpc_id            = aws_vpc.gihub-actions-aws_vpc.id
  cidr_block        = "10.90.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Private Subnet 01"
  }
}

resource "aws_subnet" "private-subnet02" {
  vpc_id            = aws_vpc.gihub-actions-aws_vpc.id
  cidr_block        = "10.90.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Private Subnet 02"
  }
}

resource "aws_internet_gateway" "github-actions-igw" {
  vpc_id = aws_vpc.gihub-actions-aws_vpc.id

  tags = {
    Name = "GitHub Actions Internet Gateway"
  }
}


resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.gihub-actions-aws_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.github-actions-igw.id
  }

  route {
    cidr_block           = var.zt_network_cidr
    network_interface_id = aws_instance.public-instance.primary_network_interface_id
  }
  tags = {
    Name = "Public Route Table"
  }
}

resource "aws_route_table_association" "public-rt-association" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_eip" "github-actions-eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "github-actions-ngw" {
  subnet_id     = aws_subnet.public-subnet.id
  allocation_id = aws_eip.github-actions-eip.id

  tags = {
    Name = "GitHub Actions NAT Gateway"
  }
}

resource "aws_route_table" "private01-rt" {
  vpc_id = aws_vpc.gihub-actions-aws_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.github-actions-ngw.id
  }

  route {
    cidr_block           = var.zt_network_cidr
    network_interface_id = aws_instance.public-instance.primary_network_interface_id
  }

  tags = {
    Name = "Private01 Route Table"
  }
}

resource "aws_route_table" "private02-rt" {
  vpc_id = aws_vpc.gihub-actions-aws_vpc.id
  tags = {
    Name = "Private02 Route Table"
  }
}

resource "aws_route_table_association" "private01-rt-association" {
  subnet_id      = aws_subnet.private-subnet01.id
  route_table_id = aws_route_table.private01-rt.id
}

resource "aws_route_table_association" "private02-rt-association" {
  subnet_id      = aws_subnet.private-subnet02.id
  route_table_id = aws_route_table.private02-rt.id
}


resource "aws_security_group" "public-sg" {
  vpc_id = aws_vpc.gihub-actions-aws_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Public Instance Security Group"
  }
}

resource "aws_instance" "public-instance" {
  ami           = "ami-04b70fa74e45c3917" # Ubuntu
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public-subnet.id
  # security_groups             = [aws_security_group.public-sg.id]
  vpc_security_group_ids      = [aws_security_group.public-sg.id]
  associate_public_ip_address = true
  key_name                    = "myAwsKeyPair"
  user_data                   = <<-EOF
    #!/bin/bash
    curl -s https://install.zerotier.com | sudo bash
    sudo zerotier-cli join ${var.zt_network_id}
  EOF

  tags = {
    Name = "Public EC2 Instance"
  }
}

// Route 53 Endpoints and Its SG
resource "aws_security_group" "route53-sg" {
  vpc_id = aws_vpc.gihub-actions-aws_vpc.id

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Route 53 Security Group"
  }
}

resource "aws_route53_resolver_endpoint" "zerotier-endpoints" {
  name      = "ZeroTier Inbound Endpoint"
  direction = "INBOUND"

  security_group_ids = [aws_security_group.route53-sg.id]

  ip_address {
    subnet_id = aws_subnet.private-subnet01.id
  }

  ip_address {
    subnet_id = aws_subnet.private-subnet02.id
  }

  protocols = ["Do53", "DoH"]


  tags = {
    Environment = "Route 53 Inbound Endpoints"
  }
}