# 1. Dashboard Visual no Amazon CloudWatch
resource "aws_cloudwatch_dashboard" "tcc_dashboard" {
  dashboard_name = "TCC-Netryon-AWS-VPN"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", aws_instance.server.id, { label = "Tráfego Recebido (VPN/IoT)" }],
            [".", "NetworkOut", ".", ".", { label = "Tráfego Enviado (Resposta AWS)" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          period  = 60
          stat    = "Sum"
          title   = "Tráfego de Rede VPN IPsec (Bytes)"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 6
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.server.id, { label = "Uso de CPU (%)" }]
          ]
          view   = "singleValue"
          region = "us-east-1"
          period = 60
          stat   = "Average"
          title  = "CPU - Gateway VPN"
        }
      },
      {
        type   = "metric"
        x      = 18
        y      = 0
        width  = 6
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", aws_instance.server.id, { label = "Falhas de Saúde (0 = OK)" }]
          ]
          view   = "singleValue"
          region = "us-east-1"
          period = 60
          stat   = "Maximum"
          title  = "Saúde da Instância EC2"
        }
      }
    ]
  })
}

# 2. Alarme de Saúde da Instância EC2
resource "aws_cloudwatch_metric_alarm" "ec2_health_alarm" {
  alarm_name          = "Saude-Gateway-VPN-AWS"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Monitora a integridade do Gateway VPN StrongSwan e Coletor IoT na AWS"

  dimensions = {
    InstanceId = aws_instance.server.id
  }

  tags = {
    Name = "Alarme-Saude-VPN-AWS"
  }
}