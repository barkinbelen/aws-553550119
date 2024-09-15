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

module "ec2" {
  source                = "../../../terraform-modules/ec2"
  project_name          = var.project_name
  env                   = var.env
  vpc_id                = module.vpc.vpc_id
  instance_name         = var.instance_name
  instance_type         = var.instance_type
  ami_id                = var.ami_id
  public_subnet_ids     = module.vpc.public_subnets[*].id
  private_subnet_ids    = module.vpc.private_subnets[*].id
  web_content_s3_bucket = aws_s3_bucket.web_content
  extra_tags            = var.extra_tags
}

# S3 Bucket with files
resource "aws_s3_bucket" "web_content" {
  bucket = "customer-prod-web-content-553550119"
  tags = merge(
    { Name = "${var.project_name}-${var.env}-Web-Content-Bucket" },
    var.extra_tags
  )
}

resource "aws_s3_object" "example_file" {
  bucket = aws_s3_bucket.web_content.bucket
  key    = "index.html"
  source = "index.html"
}

