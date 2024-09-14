terraform {
  backend "s3" {
    bucket         = "customer-prod-terraform-state-553550119"
    key            = "customer-prod-us-west-2.tfstate"
    region         = "us-west-2"
    profile        = "prod-customer"
    session_name   = "barkinbelen"
    dynamodb_table = "terraform_state"
    encrypt        = true
  }
}
