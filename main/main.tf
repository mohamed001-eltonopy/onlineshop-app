# Configure the AWS Provider
provider "aws"{
  region = "us-east-1"
}

variable vpc-cidr-block {}
variable subnet-cidr-block {}
variable avail_zone {}
variable env_prefix {}
variable my_ip {}
variable ssh_key {}
variable instance_type {}
variable private_key_location {}



resource "aws_vpc" "development-vpc" {
  cidr_block = var.vpc-cidr-block
  tags = {
    Name = "${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.development-vpc.id
  cidr_block = var.subnet-cidr-block
  availability_zone = var.avail_zone
  tags = {
    Name = "${var.env_prefix}-subnet"
  }
}


resource "aws_route_table" "myapp-route-table" {
   vpc_id = aws_vpc.development-vpc.id

   route {
     cidr_block = "0.0.0.0/0"
     gateway_id = aws_internet_gateway.myapp-igw.id
   }

   # default route, mapping VPC CIDR block to "local", created implicitly and cannot be specified.

   tags = {
     Name = "${var.env_prefix}-route-table"
   }
 }

resource "aws_internet_gateway" "myapp-igw" {
	vpc_id = aws_vpc.development-vpc.id
    
    tags = {
     Name = "${var.env_prefix}-internet-gateway"
   }
}

# Associate subnet with Route Table
resource "aws_route_table_association" "a-rtb-subnet" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.myapp-route-table.id
}

resource "aws_security_group" "myapp-sg" {
  name   = "myapp-sg"
  vpc_id = aws_vpc.development-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name = "${var.env_prefix}-sg"
  }
}


data "aws_ami" "amazon-linux-image" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "ssh-key" {
  key_name   = "myapp-key"
  public_key = file(var.ssh_key)
}



resource "aws_instance" "myapp-server" {
  ami                         = data.aws_ami.amazon-linux-image.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.ssh-key.id
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.main.id
  vpc_security_group_ids      = [aws_security_group.myapp-sg.id]
  availability_zone			      = var.avail_zone

  tags = {
    Name = "${var.env_prefix}-server"
  }
}

output "server-ip" {
    value = aws_instance.myapp-server.public_ip
}



output "ami_id" {
  value = data.aws_ami.amazon-linux-image.id
}




output "dev-vpc-id" {
  value = aws_vpc.development-vpc.id
}


output "dev-subnet-id" {
  value = aws_subnet.main.id
}
