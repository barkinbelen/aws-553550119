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

### IAM Roles and Policies ###

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

### AUTO SCALING GROUP ###

# Launch template for the EC2 instances
resource "aws_launch_template" "web_server_launch_template" {
  name_prefix            = "${var.project_name}-${var.env}-"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web_server_sg.id]
  iam_instance_profile {
    name = aws_iam_instance_profile.web_server_ec2_instance_profile.name
  }

  # User data script to configure the instance
  user_data = base64encode(templatefile("${path.module}/user_data.tpl", {
    s3_bucket_name       = var.web_content_s3_bucket.bucket,
    cloudwatch_log_group = aws_cloudwatch_log_group.nginx_access_logs.name
  }))


  # Tags for the EC2 instances launched with this template
  tags = merge(
    { Name = "${var.project_name}-${var.env}-Launch-Template" },
    var.extra_tags
  )
}

# Auto Scaling Group (ASG) to manage EC2 instances
resource "aws_autoscaling_group" "web_server_asg" {
  launch_template {
    id      = aws_launch_template.web_server_launch_template.id
    version = "$Latest"
  }
  name                      = "${var.project_name}-${var.env}-Web-Server-ASG"
  vpc_zone_identifier       = [var.subnet_id]
  min_size                  = 1
  max_size                  = 3
  desired_capacity          = 1
  health_check_type         = "EC2"
  health_check_grace_period = 300

  # Tags for instances in the Auto Scaling Group
  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.env}-Web-Server-ASG"
    propagate_at_launch = true
  }
  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = var.env
    propagate_at_launch = true
  }
  tag {
    key                 = "Owner"
    value               = "DevOps Admin"
    propagate_at_launch = true
  }
}

### SCALING POLICIES ###

# Policy to scale up when CPU usage increases
resource "aws_autoscaling_policy" "web_server_scale_up" {
  name                   = "${var.project_name}-${var.env}-Scale-Up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.web_server_asg.name
}

# Policy to scale down when CPU usage decreases
resource "aws_autoscaling_policy" "web_server_scale_down" {
  name                   = "${var.project_name}-${var.env}-Scale-Down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.web_server_asg.name
}

### CLOUDWATCH METRIC ALARMS ###

# CloudWatch alarm to trigger scale-up when CPU is high
resource "aws_cloudwatch_metric_alarm" "web_server_cpu_high" {
  alarm_name          = "${var.project_name}-${var.env}-CPU-High"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"
  alarm_actions       = [aws_autoscaling_policy.web_server_scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_server_asg.name
  }

  tags = merge(
    { Name = "${var.project_name}-${var.env}-CPU-High" },
    var.extra_tags
  )
}

# CloudWatch alarm to trigger scale-down when CPU is low
resource "aws_cloudwatch_metric_alarm" "web_server_cpu_low" {
  alarm_name          = "${var.project_name}-${var.env}-CPU-Low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "20"
  alarm_actions       = [aws_autoscaling_policy.web_server_scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_server_asg.name
  }

  tags = merge(
    { Name = "${var.project_name}-${var.env}-CPU-Low" },
    var.extra_tags
  )
}
