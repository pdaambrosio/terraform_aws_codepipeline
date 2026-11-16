provider "aws" {
  region  = var.region
  version = "~> 2.0"
}

terraform {
  backend "s3" {
    bucket = "pdajgs-terraform"
    key    = "webapp.tfstate"
    region = "us-east-1"
  }
}