terraform {
  backend "s3" {
    bucket         = "customer-prod-terraform-state-553550119"
    key            = "customer-prod-us-west-2.tfstate"
    region         = "us-west-2"
    profile        = "default" # Optional AWS Profile name in ~/.aws/credentials.
    session_name   = "DevOpsAdmin"
    dynamodb_table = "terraform_state"
    encrypt        = true
  }
}
