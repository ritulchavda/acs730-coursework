packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.3.9, < 2.0.0"
    }
  }
}

variable "base_ami" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "ami_name" {
  type = string
}

source "amazon-ebs" "web" {
  region                      = "us-east-1"
  source_ami                  = var.base_ami
  subnet_id                   = var.subnet_id
  security_group_id           = var.security_group_id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  iam_instance_profile        = "LabInstanceProfile"

  communicator              = "none"
  ssh_interface             = "session_manager"
  ssh_username              = "ec2-user"
  ssh_timeout               = "10m"
  ssh_clear_authorized_keys = true

  ami_name = var.ami_name

  run_tags = {
    Name = "acs730-lab6-packer-builder"
    Lab  = "lab6"
  }

  tags = {
    Name = var.ami_name
    Lab  = "lab6"
  }

  snapshot_tags = {
    Name = var.ami_name
    Lab  = "lab6"
  }
}

build {
  sources = ["source.amazon-ebs.web"]

  provisioner "shell-local" {
    environment_vars = [
      "LAB6_BUILDER_ID=${build.ID}",
      "LAB6_INDEX_HTML=${abspath("${path.root}/files/index.html")}",
      "LAB6_WAIT_SSM=${abspath("${path.root}/../scripts/wait-ssm.sh")}"
    ]
    script = "${path.root}/provision-web.sh"
  }
}
