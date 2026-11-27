terraform {
  backend "s3" {
    bucket       = "acs730-tfstate-231074812996"
    key          = "assignment1/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
