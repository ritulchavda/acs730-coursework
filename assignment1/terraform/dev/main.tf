provider "aws" {
  region = "us-east-1"
}

variable "owner" {
  description = "Your Seneca username, used in resource names."
  type        = string
}

module "web" {
  source = "../modules/web"

  project       = "acs730-a1-dev"
  environment   = "dev"
  owner         = var.owner
  instance_type = "t3.micro"
  vpc_cidr      = "10.42.0.0/16"

  public_subnets = {
    a = { cidr_block = "10.42.1.0/24", az_index = 0 }
    b = { cidr_block = "10.42.2.0/24", az_index = 1 }
  }
}

output "web_url" {
  description = "URL of the dev web server."
  value       = module.web.web_url
}
