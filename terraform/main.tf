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
resource "aws_key_pair" "builder_key" {
  key_name   = "builder-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Fetch the default VPC and public subnet
data "aws_vpc" "default" {
  id = "vpc-044604d0bfb707142"
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Create a security group
resource "aws_security_group" "builder_sg" {
  name        = "builder-security-group"
  description = "Security group for builder EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR_IP/32"]  # Replace with your actual IP
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
  ami                    = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2 AMI ID (update as needed)
  instance_type          = "t3.medium"
  key_name               = aws_key_pair.builder_key.key_name
  vpc_security_group_ids = [aws_security_group.builder_sg.id]
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
  value       = aws_security_group.builder_sg.id
  description = "ID of the security group"
}
