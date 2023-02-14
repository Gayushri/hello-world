provider "aws" {
  region = "ap-south-1"
}

#Creating vpc, CIDR with tags
resource "aws_vpc" "web" {
  cidr_block       = "10.0.0.0/24"
  instance_tenancy = "default"

  tags = {
    Name = "web"
  }
}

#Creating public subnets to vpc
resource "aws_subnet" "web-public1" {
  vpc_id                  = aws_vpc.web.id
  cidr_block              = "10.0.0.0/25"
  map_public_ip_on_launch = "true"
  availability_zone       = "ap-south-1a"

  tags = {
    Name = "web-public1"
  }
}

#Creating private subnets to vpc
resource "aws_subnet" "web-private1" {
  vpc_id                  = aws_vpc.web.id
  cidr_block              = "10.0.0.128/26"
  map_public_ip_on_launch = "false"
  availability_zone       = "ap-south-1b"

  tags = {
    Name = "web-private1"
  }
}

#creating IGW to VPC
resource "aws_internet_gateway" "web-gw" {
  vpc_id = aws_vpc.web.id

  tags = {
    Name = "web"
  }
}
#creating routing table
resource "aws_route_table" "web-public1" {
  vpc_id = aws_vpc.web.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.web-gw.id
  }

  tags = {
    Name = "web-public1"
  }
}

#creating routing table
resource "aws_route_table" "web-private1" {
  vpc_id = aws_vpc.web.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.web-gw.id
  }

  tags = {
    Name = "web-private1"
  }
}


#create route associations with public
resource "aws_route_table_association" "web-public1" {
  subnet_id      = aws_subnet.web-public1.id
  route_table_id = aws_route_table.web-public1.id
}

#create route associations with private
resource "aws_route_table_association" "web-private1" {
  subnet_id      = aws_subnet.web-private1.id
  route_table_id = aws_route_table.web-private1.id
}


resource "aws_security_group" "allow_tls" {

  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.web.id
  
  
  ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

#creating EC2
resource "aws_instance" "server1" {
  ami                         = "ami-0be0a52ed3f231c12"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.web-public1.id
  vpc_security_group_ids      = [aws_security_group.allow_tls.id]
  associate_public_ip_address = true
  key_name                    = "Pkey"

  tags = {
    Name = "server1"
  }


  connection {
    host        = aws_instance.server1.public_ip
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("ansible.pem")

  }

  provisioner "local-exec" {
    command = "echo ${self.public_ip} > /etc/ansible/hosts"
    
    
}
   
}

resource "null_resource" "previous" {}

resource "time_sleep" "wait_2_minutes" {
  depends_on = [null_resource.previous]

  create_duration = "2m"
}



resource "null_resource" "run_ansible" {

  depends_on = [time_sleep.wait_2_minutes]
  connection {
    host        = aws_instance.server1.public_ip
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("ansible.pem")

  }

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False sudo ansible-playbook -u ubuntu -i '${aws_instance.server1.public_ip},' play.yml"
  }
}
