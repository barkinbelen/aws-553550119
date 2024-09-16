output "load_balancer_url" {
  description = "Load Balancer URL"
  value       = aws_lb.web_server_alb.dns_name
}
