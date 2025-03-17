provider "aws" {
  region = "us-east-1"
}

# Generate an SSH key pair
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save the private key locally
resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/builder_key.pem"
  file_permission = "0600"
}

# Create an AWS key pair using the public key
data "aws_key_pair" "existing_key" {
  key_name = "builder-key"
}

resource "aws_key_pair" "builder_key" {
  count      = length(data.aws_key_pair.existing_key.id) > 0 ? 0 : 1
  key_name   = "builder-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# resource "aws_key_pair" "builder_key" {
#   key_name   = "builder-key"
#   public_key = tls_private_key.ssh_key.public_key_openssh

#   lifecycle {
#     ignore_changes = [public_key]
#   }
# }

# Fetch the default VPC and public subnet
data "aws_vpc" "default" {
  id = "vpc-044604d0bfb707142"
}

# Get all subnets within the VPC
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

######################################################
# Get all security groups associated with the VPC
data "aws_security_groups" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Get all route tables in the VPC
data "aws_route_tables" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Get internet gateway if exists
data "aws_internet_gateway" "default" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Get NAT gateways
data "aws_nat_gateways" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
######################################################

# Create a security group
data "aws_security_group" "existing_sg" {
  filter {
    name   = "group-name"
    values = ["builder-security-group"]
  }
}

resource "aws_security_group" "builder_sg" {
  count       = length(data.aws_security_group.existing_sg.id) > 0 ? 0 : 1
  name        = "builder-security-group"
  description = "Security group for builder EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["172.26.187.145/32"]  # Replace with your actual IP
    # eth0      Link encap:Ethernet  HWaddr 00:15:5D:76:83:7F  
    #       inet addr:172.26.187.145  Bcast:172.26.191.255  Mask:255.255.240.0
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5001
    to_port     = 5001
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

# Launch EC2 instance
resource "aws_instance" "builder" {
  ami                    = "ami-01f5a0b78d6089704"  # Amazon Linux 2 AMI ID (update as needed)
  instance_type          = "t3.medium"
  key_name               = data.aws_key_pair.existing_key.key_name  # might be .id
  vpc_security_group_ids = [data.aws_security_group.existing_sg.id]
  subnet_id              = tolist(data.aws_subnets.public.ids)[0]
  associate_public_ip_address = true

  tags = {
    Name = "builder"
  }
}

# Output values
output "public_ip" {
  value       = aws_instance.builder.public_ip
  description = "Public IP of the EC2 instance"
}

output "ssh_private_key_path" {
  value       = local_file.private_key.filename
  description = "Path to the generated private SSH key"
  sensitive   = true
}

output "security_group_id" {
  value       = data.aws_security_group.existing_sg.id
  description = "ID of the security group"
}

# Output values
output "vpc_id" {
  value = data.aws_vpc.default.id
}

output "subnets" {
  value = data.aws_subnets.public.ids
}

output "security_groups" {
  value = data.aws_security_groups.default.ids
}

output "route_tables" {
  value = data.aws_route_tables.default.ids
}

output "internet_gateway" {
  value = data.aws_internet_gateway.default.id
}

output "nat_gateways" {
  value = data.aws_nat_gateways.default.ids
}