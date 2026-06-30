terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_ecr_repository" "devops_api" {
  name                 = "devops-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ---------------------------
# SSH Key Pair
# ---------------------------
resource "aws_key_pair" "devops_api_key" {
  key_name   = "devops-api-key"
  public_key = file("${path.module}/devops-api-key.pub")
}

# ---------------------------
# Security Group
# ---------------------------
resource "aws_security_group" "devops_api_sg" {
  name        = "devops-api-sg"
  description = "Allow SSH and API traffic"

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "API access"
    from_port   = 3000
    to_port     = 3000
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
    Name = "devops-api-sg"
  }
}

# ---------------------------
# IAM Role for EC2
# ---------------------------
resource "aws_iam_role" "ec2_ecr_role" {
  name = "devops-api-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# ---------------------------
# IAM Policy - least privilege ECR pull only
# ---------------------------
resource "aws_iam_role_policy" "ecr_pull_policy" {
  name = "ecr-pull-only-policy"
  role = aws_iam_role.ec2_ecr_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = aws_ecr_repository.devops_api.arn
      }
    ]
  })
}

# ---------------------------
# Instance Profile - links role to EC2
# ---------------------------
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "devops-api-instance-profile"
  role = aws_iam_role.ec2_ecr_role.name
}

# ---------------------------
# Get latest Amazon Linux 2023 AMI
# ---------------------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# ---------------------------
# Current AWS account info (needed for user_data)
# ---------------------------
data "aws_caller_identity" "current" {}

# ---------------------------
# EC2 Instance
# ---------------------------
resource "aws_instance" "devops_api_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.devops_api_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name                = aws_key_pair.devops_api_key.key_name

  user_data = <<-EOF
              #!/bin/bash
              set -e
              dnf install -y docker
              systemctl start docker
              systemctl enable docker

              aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.ap-south-1.amazonaws.com

              docker pull ${aws_ecr_repository.devops_api.repository_url}:latest
              docker run -d -p 3000:3000 --restart unless-stopped ${aws_ecr_repository.devops_api.repository_url}:latest
              EOF

  user_data_replace_on_change = true

  tags = {
    Name = "devops-api-server"
  }
}