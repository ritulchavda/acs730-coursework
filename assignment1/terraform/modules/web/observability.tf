variable "environment" {
  description = "Deployment environment used to locate its application parameter."
  type        = string
}

data "aws_ssm_parameter" "db_password" {
  name            = "/acs730/assignment1/${var.environment}/db-password"
  with_decryption = false
}

output "app_parameter_name" {
  description = "Name of the application parameter read from SSM."
  value       = data.aws_ssm_parameter.db_password.name
}

resource "aws_cloudwatch_metric_alarm" "web_cpu" {
  alarm_name          = "${local.name}-cpu-high"
  alarm_description   = "Average web instance CPU exceeds 80 percent over five minutes."
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"

  dimensions = {
    InstanceId = aws_instance.web.id
  }
}
