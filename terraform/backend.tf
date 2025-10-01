terraform {
  backend "s3" {
    bucket         = "REPLACE_ME-state-bucket"
    key            = "semester3/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "REPLACE_ME-terraform-locks"
    encrypt        = true
  }
} 