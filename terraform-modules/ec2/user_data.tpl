#!/bin/bash
# Update the system and install Nginx
yum update -y
yum install -y nginx

# Create directory for your website
mkdir -p /var/www/html

# Download the index.html from S3 bucket
aws s3 sync s3://${s3_bucket_name}/ /var/www/html/

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

# Install and configure the CloudWatch agent for log monitoring
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
            "log_group_name": "${cloudwatch_log_group}",
            "log_stream_name": "$(date +'%Y-%m-%d-%H-%M')/{instance_id}",  # Logs in 30-minute intervals
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
EOT

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Start and enable Nginx
systemctl restart nginx
systemctl enable nginx
