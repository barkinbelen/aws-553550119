# Create Security Group for Web Server
resource "aws_security_group" "web_server_sg" {
  vpc_id      = var.vpc_id
  description = "Web Server Security Group"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(
    { Name = "${var.project_name}-${var.env}-Web-Server-SG" },
    var.extra_tags
  )
}

# Web Server IAM Role
resource "aws_iam_role" "web_server_iam_role" {
  name = "${var.project_name}-${var.env}-Web-Server-IAM-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = var.extra_tags
}

# S3 Access IAM Policy
resource "aws_iam_policy" "web_server_s3_access_policy" {
  name        = "${var.project_name}-${var.env}-Web-Server-S3-Access-Policy"
  description = "Policy to allow EC2 instances to access specific S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "${var.web_content_s3_bucket.arn}"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${var.web_content_s3_bucket.arn}/*"
      }
    ]
  })
  tags = var.extra_tags
}

# Attach S3 Access Policy to Role
resource "aws_iam_role_policy_attachment" "s3_access_role_policy_attachment" {
  policy_arn = aws_iam_policy.web_server_s3_access_policy.arn
  role       = aws_iam_role.web_server_iam_role.name
}

# Web Server IAM Instance Profile
resource "aws_iam_instance_profile" "web_server_ec2_instance_profile" {
  name = "${var.project_name}-${var.env}-Web-Server-Instance-Profile"
  role = aws_iam_role.web_server_iam_role.name
  tags = var.extra_tags
}

# Web Server EC2 Instance
resource "aws_instance" "web_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.web_server_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.web_server_ec2_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              # Update the system and install Nginx
              yum update -y
              yum install -y nginx

              # Create directory for your website
              mkdir -p /var/www/html

              # Download the index.html from S3 bucket
              aws s3 sync s3://${var.web_content_s3_bucket.bucket}/ /var/www/html/

              # Overwrite the Nginx configuration with your desired setup
              cat <<EOT > /etc/nginx/nginx.conf
              user nginx;
              worker_processes auto;
              error_log /var/log/nginx/error.log notice;
              pid /run/nginx.pid;

              events {
                  worker_connections 1024;
              }

              http {
                  log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                                    '\$status \$body_bytes_sent "\$http_referer" '
                                    '"\$http_user_agent" "\$http_x_forwarded_for"';
                  access_log  /var/log/nginx/access.log  main;

                  sendfile        on;
                  tcp_nopush      on;
                  keepalive_timeout 65;
                  types_hash_max_size 2048;

                  include       /etc/nginx/mime.types;
                  default_type  application/octet-stream;

                  include /etc/nginx/conf.d/*.conf;

                  server {
                      listen       80 default_server;
                      listen       [::]:80 default_server;
                      server_name  _;
                      root         /var/www/html;
                      index        index.html;

                      location / {
                          try_files \$uri \$uri/ =404;
                      }

                      error_page 404 /404.html;
                      error_page 500 502 503 504 /50x.html;
                  }
              }
              EOT
              yum install -y amazon-cloudwatch-agent

              # Create CloudWatch Agent configuration file
              cat <<EOT > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
              {
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [
                        {
                          "file_path": "/var/log/nginx/access.log",
                          "log_group_name": "${aws_cloudwatch_log_group.nginx_access_logs.name}",
                          "log_stream_name": "$(date +'%Y-%m-%d')/{instance_id}",
                          "timezone": "UTC"
                        }
                      ]
                    }
                  }
                }
              }
              EOT

              # Configure and start the CloudWatch Agent
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
                -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

              # Start and enable Nginx
              systemctl restart nginx
              systemctl enable nginx
              EOF

  tags = merge(
    { Name = "${var.project_name}-${var.env}-${var.instance_name}" },
    var.extra_tags
  )
}

# CloudWatch Log Group and IAM Policy for Nginx Access Logs
resource "aws_cloudwatch_log_group" "nginx_access_logs" {
  name = "${var.project_name}-${var.env}-Web-Server-Nginx-Access-Logs"
  tags = var.extra_tags
}

resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name        = "${var.project_name}-${var.env}-Web-Server-Cloudwatch-Logs-Policy"
  description = "Policy to allow EC2 instances to send logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = [
          "${aws_cloudwatch_log_group.nginx_access_logs.arn}",
          "${aws_cloudwatch_log_group.nginx_access_logs.arn}:*"
        ]

      }
    ]
  })
  tags = var.extra_tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs_policy_attachment" {
  policy_arn = aws_iam_policy.cloudwatch_logs_policy.arn
  role       = aws_iam_role.web_server_iam_role.name
}
