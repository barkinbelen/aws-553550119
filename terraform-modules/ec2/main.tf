locals {
  common_resource_name = "${var.project_name}-${var.env}-${var.instance_name}"
}

#######################
### SECURITY GROUPS ###
#######################

# Create Security Group for Web Server
resource "aws_security_group" "web_server_sg" {
  vpc_id      = var.vpc_id
  description = "${var.instance_name} Security Group"

  # Allow inbound traffic from ALB security group
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web_server_alb_sg.id]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    { Name = "${local.common_resource_name}-Instance-SG" },
    var.extra_tags
  )
}

# Create Security Group for ALB
resource "aws_security_group" "web_server_alb_sg" {
  vpc_id      = var.vpc_id
  description = "Security Group for ALB"

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
    { Name = "${local.common_resource_name}-ALB-SG" },
    var.extra_tags
  )
}

##############################
### IAM ROLES AND POLICIES ###
##############################

# Web Server IAM Role
resource "aws_iam_role" "web_server_iam_role" {
  name = "${local.common_resource_name}-IAM-Role"

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
  name        = "${local.common_resource_name}-S3-Access-Policy"
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
  name = "${local.common_resource_name}-Instance-Profile"
  role = aws_iam_role.web_server_iam_role.name
  tags = var.extra_tags
}

# CloudWatch Log Group and IAM Policy for Nginx Access Logs
resource "aws_cloudwatch_log_group" "nginx_access_logs" {
  name = "${local.common_resource_name}-Nginx-Access-Logs"
  tags = var.extra_tags
}

resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name        = "${local.common_resource_name}-Cloudwatch-Logs-Policy"
  description = "Policy to allow EC2 instances to send logs and metrics to CloudWatch"

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
      },
      {
        Effect   = "Allow",
        Action   = "cloudwatch:PutMetricData",
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
  tags = var.extra_tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs_policy_attachment" {
  policy_arn = aws_iam_policy.cloudwatch_logs_policy.arn
  role       = aws_iam_role.web_server_iam_role.name
}

#####################
### LOAD BALANCER ###
#####################

# Create the Application Load Balancer
resource "aws_lb" "web_server_alb" {
  name               = "${local.common_resource_name}-ALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_server_alb_sg.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = merge(
    { Name = "${local.common_resource_name}-ALB" },
    var.extra_tags
  )
}

# Create the ALB target group
resource "aws_lb_target_group" "web_server_tg" {
  name     = "${local.common_resource_name}-TG-80"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = merge(
    { Name = "${local.common_resource_name}-TG-80" },
    var.extra_tags
  )
}

# Create the ALB listener
resource "aws_lb_listener" "web_server_listener" {
  load_balancer_arn = aws_lb.web_server_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_server_tg.arn
  }

  tags = merge(
    { Name = "${local.common_resource_name}-Listener-80" },
    var.extra_tags
  )
}

##########################
### AUTO SCALING GROUP ###
##########################

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
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [aws_lb_target_group.web_server_tg.arn]
  min_size                  = 1
  max_size                  = 4
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

########################
### SCALING POLICIES ###
########################

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

################################
### CLOUDWATCH METRIC ALARMS ###
################################

# CloudWatch alarm to trigger scale-up when CPU is high
resource "aws_cloudwatch_metric_alarm" "web_server_cpu_high" {
  alarm_name          = "${var.project_name}-${var.env}-CPU-High-Scale-Up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "5"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "60"
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
  alarm_name          = "${var.project_name}-${var.env}-CPU-Low-Scale-Down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "5"
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

# CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "web_server_cpu_high_alarm" {
  alarm_name          = "${local.common_resource_name}-CPU-High"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "5"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"
  alarm_actions       = [aws_sns_topic.alarm_notifications.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_server_asg.name
  }
}

# Memory Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "web_server_memory_high_alarm" {
  alarm_name          = "${local.common_resource_name}-Memory-High"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_actions       = [aws_sns_topic.alarm_notifications.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_server_asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "web_server_disk_space_high_alarm" {
  alarm_name          = "${local.common_resource_name}-Disk-Space-High"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_actions       = [aws_sns_topic.alarm_notifications.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_server_asg.name
  }
}

##################################
### SNS TOPIC AND SUBSCRIPTION ###
##################################

# SNS topic for alarm notifications
resource "aws_sns_topic" "alarm_notifications" {
  name = "${local.common_resource_name}-alarm-notifications"
}

# Subscribe your email to the SNS topic
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.alarm_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email # Specify the email where you want to receive notifications
}
