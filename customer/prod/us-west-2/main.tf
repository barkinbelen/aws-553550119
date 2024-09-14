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

