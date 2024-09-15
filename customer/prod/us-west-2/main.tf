# VPC module to create required VPC resources
module "vpc" {
  source                  = "../../../terraform-modules/vpc"
  project_name            = var.project_name
  env                     = var.env
  region                  = var.region
  cidr_block              = var.cidr_block
  subnet_count            = var.subnet_count
  public_subnet_suffixes  = var.public_subnet_suffixes
  private_subnet_suffixes = var.private_subnet_suffixes
  extra_tags              = var.extra_tags
}

# S3 Bucket with files
resource "aws_s3_bucket" "web_content" {
  bucket = "customer-prod-web-content-553550119"

  tags = {
    Name = "${var.project_name}-${var.env}-Web-Content-Bucket"
  }
}

resource "aws_s3_object" "example_file" {
  bucket = aws_s3_bucket.web_content.bucket
  key    = "index.html"
  source = "index.html"
}

