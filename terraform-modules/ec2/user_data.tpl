#!/bin/bash
# Update the system, install Nginx and CloudWatch Agent
yum update -y
yum install -y nginx amazon-cloudwatch-agent

# Create directory for your website
mkdir -p /var/www/html

# Download the website files from S3 bucket
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
    }
}
EOT

# Create CloudWatch Agent configuration file for Nginx logs and EC2 metrics
cat <<EOT > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "metrics": {
    "aggregation_dimensions": [
      [
        "AutoScalingGroupName"
      ]
    ],
    "append_dimensions": {
      "AutoScalingGroupName": "XXX{aws:AutoScalingGroupName}"
    },
    "metrics_collected": {
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      },
      "statsd": {
        "metrics_aggregation_interval": 60,
        "metrics_collection_interval": 10,
        "service_address": ":8125"
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "${cloudwatch_log_group}",
            "log_stream_name": "$(date +'%Y-%m-%d-%H')/nginx-access-{instance_id}",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/nginx/error.log",
            "log_group_name": "${cloudwatch_log_group}",
            "log_stream_name": "$(date +'%Y-%m-%d-%H')/nginx-error-{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
EOT
# Replace XXX with $ This is done because while sending the script terraform is trying give a value to $${aws:AutoScalingGroupName} and this is causing problems.
sed -i 's/XXX/\$/g' /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Start and enable Nginx
systemctl restart nginx
systemctl enable nginx
