provider "aws" {
  region = "us-east-1"
}

module "security_baseline" {
  source = "./modules/security-baseline"
}