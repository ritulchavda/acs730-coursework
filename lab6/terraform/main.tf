terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "subnet_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

data "aws_subnet" "target" {
  id = var.subnet_id
}

data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "base" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  base_ami = nonsensitive(data.aws_ssm_parameter.base.value)
}

resource "aws_security_group" "web" {
  name_prefix = "acs730-lab6-"
  description = "Lab 6 target with outbound access and no inbound rules"
  vpc_id      = data.aws_subnet.target.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "acs730-lab6-web", Lab = "lab6" }
}

resource "aws_instance" "web" {
  ami                         = local.base_ami
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.target.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.web.id]
  iam_instance_profile        = "LabInstanceProfile"

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "acs730-lab6-target"
    Lab  = "lab6"
    Role = "web"
  }
}

output "instance_id" {
  value = aws_instance.web.id
}

output "security_group_id" {
  value = aws_security_group.web.id
}

output "subnet_id" {
  value = data.aws_subnet.target.id
}

output "instance_type" {
  value = aws_instance.web.instance_type
}

output "base_ami" {
  value = local.base_ami
}

output "ssm_bucket" {
  value = "acs730-lab6-ssm-${data.aws_caller_identity.current.account_id}"
}
