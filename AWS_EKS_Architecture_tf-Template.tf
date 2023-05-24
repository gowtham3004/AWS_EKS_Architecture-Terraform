provider "aws" {
  region = "ap-south-1"  # Replace with your desired region
}

# Configure Terraform backend for storing state file in S3
terraform {
  backend "s3" {
    bucket = "AWS_EKS_bucket"
    key    = "terraform.tfstate"
    region = "ap-south-1"
  }
}

# Create VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create Public Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.128.0/20"
  availability_zone = "ap-south-1a"
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.144.0/20"
  availability_zone = "ap-south-1b"
}

resource "aws_subnet" "public_subnet_3" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.160.0/20"
  availability_zone = "ap-south-1c"
}

# Create Private Subnets
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.0.0/19"
  availability_zone = "ap-south-1a"
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.32.0/19"
  availability_zone = "ap-south-1b"
}

resource "aws_subnet" "private_subnet_3" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.64.0/19"
  availability_zone = "ap-south-1c"
}

# Create Security Group for Bastion Host
resource "aws_security_group" "bastion_security_group" {
  name        = "bastion-security-group"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
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

# Create Bastion Host EC2 Instance
resource "aws_instance" "bastion_instance" {
  ami           = "ami-12345678"  # Replace with your desired AMI ID
  instance_type = "t2.micro"
  key_name      = "my-key-pair"  # Replace with your key pair

  subnet_id              = aws_subnet.public_subnet_1.id
  vpc_security_group_ids = [aws_security_group.bastion_security_group.id]

  # Add user_data script here to configure bastion host
  # Example:
  # user_data = <<-EOF
  #   #!/bin/bash
  #   # Install necessary packages and configure bastion host
  #   ...
  #   EOF
}

# Create NAT Gateways
resource "aws_nat_gateway" "nat_gateway_1" {
  allocation_id = aws_eip.nat_eip_1.id
  subnet_id     = aws_subnet.public_subnet_1.id
}

resource "aws_nat_gateway" "nat_gateway_2" {
  allocation_id = aws_eip.nat_eip_2.id
  subnet_id     = aws_subnet.public_subnet_2.id
}

resource "aws_nat_gateway" "nat_gateway_3" {
  allocation_id = aws_eip.nat_eip_3.id
  subnet_id     = aws_subnet.public_subnet_3.id
}

# Create Elastic IPs for NAT Gateways
resource "aws_eip" "nat_eip_1" {
  vpc = true
}

resource "aws_eip" "nat_eip_2" {
  vpc = true
}

resource "aws_eip" "nat_eip_3" {
  vpc = true
}

# Create Autoscaling Group for Bastion Host
resource "aws_autoscaling_group" "bastion_autoscaling_group" {
  name                 = "bastion-autoscaling-group"
  max_size             = 1
  min_size             = 1
  desired_capacity     = 1
  launch_configuration = aws_launch_configuration.bastion_launch_configuration.name
  vpc_zone_identifier  = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id, aws_subnet.public_subnet_3.id]
}

resource "aws_launch_configuration" "bastion_launch_configuration" {
  name_prefix          = "bastion-launch-configuration"
  image_id             = "ami-12345678"  # Replace with your desired AMI ID
  instance_type        = "t2.micro"
  key_name             = "my-key-pair"  # Replace with your key pair
  security_groups      = [aws_security_group.bastion_security_group.id]
  associate_public_ip_address = true

  # Add user_data script here to configure bastion host
  # Example:
  # user_data = 
  #   #!/bin/bash
  #   # Install necessary packages and configure bastion host
  #   ...
  #   EOF
}

# Create Elastic Load Balancer
resource "aws_elb" "kubernetes_elb" {
  name               = "kubernetes-elb"
  subnets            = [aws_subnet.private_subnet_1.id,aws_subnet.private_subnet_2.id,aws_subnet.private_subnet_3.id]
  security_groups    = [aws_security_group.worker_nodes_security_group.id]
  cross_zone_load_balancing = true

  listener {
    instance_port     = 8080
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}

# Create EKS Cluster
resource "aws_eks_cluster" "my_cluster" {
  name     = "my-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.private_subnet_1.id,
      aws_subnet.private_subnet_2.id,
      aws_subnet.private_subnet_3.id
    ]
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  name = "my-cluster-role"
  assume_role_policy = "AmazonEksaccess"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
}

# Create EKS Worker Nodes
resource "aws_launch_configuration" "eks_worker_nodes_launch_configuration" {
  name_prefix          = "eks-worker-nodes-launch-configuration"
  image_id             = "ami-12345678"  # Replace with your desired AMI ID
  instance_type        = "t2.micro"
  key_name             = "my-key-pair"  # Replace with your key pair
  security_groups      = [aws_security_group.worker_nodes_security_group.id]
  associate_public_ip_address = false
}

resource "aws_autoscaling_group" "eks_worker_nodes_autoscaling_group" {
  name                 = "eks-worker-nodes-autoscaling-group"
  max_size             = 2
  min_size             = 2
  desired_capacity     = 2
  launch_configuration = aws_launch_configuration.eks_worker_nodes_launch_configuration.name
  vpc_zone_identifier  = [aws_subnet.private_subnet_2.id, aws_subnet.private_subnet_3.id]
}

# Create Kubernetes Control Plane Components
resource "kubernetes_deployment" "control_plane" {
  metadata {
    name = "control-plane"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "control-plane"
      }
    }

    template {
      metadata {
        labels = {
          app = "control-plane"
        }
      }

      spec {
        // Configure your control plane components here
      }
    }
  }
}

# Create Amazon RDS Instance
resource "aws_db_instance" "rds_instance" {
  identifier             = "my-rds-instance"
  engine                 = "mysql"
  instance_class         = "db.t2.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  username               = "admin"
  password               = "password"
  vpc_security_group_ids = [aws_security_group.rds_security_group.id]
  multi_az               = true
  availability_zone      = "ap-south-1b"
}

# Create Security Group for Worker Nodes
resource "aws_security_group" "worker_nodes_security_group" {
  name        = "worker-nodes-security-group"
  description = "Security group for worker nodes"
  vpc_id      = aws_vpc.my_vpc.id

  # Add inbound and outbound rules as needed for your application
  ingress {
    from_port   = 0
    to_port     = 65535
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

# Create Security Group for RDS Instance
resource "aws_security_group" "rds_security_group" {
  name        = "rds-security-group"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.my_vpc.id

  # Add inbound and outbound rules as needed for your RDS instance
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.worker_nodes_security_group.id]
  }
}