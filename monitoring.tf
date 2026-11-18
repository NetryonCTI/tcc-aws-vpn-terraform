# 1. Dashboard Visual Completo no Amazon CloudWatch
resource "aws_cloudwatch_dashboard" "tcc_dashboard" {
  dashboard_name = "TCC-Netryon-AWS-VPN"

  dashboard_body = jsonencode({
    widgets = [
      # --- LINHA 1 ---
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
      },

      # --- LINHA 2 ---
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "NetworkPacketsIn", "InstanceId", aws_instance.server.id, { label = "Pacotes Recebidos (Pkts)" }],
            [".", "NetworkPacketsOut", ".", ".", { label = "Pacotes Enviados (Pkts)" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          period  = 60
          stat    = "Sum"
          title   = "Volume de Pacotes - Túnel IPsec & Telemetria"
        }
      },
      {
        type   = "alarm"
        x      = 12
        y      = 6
        width  = 6
        height = 6
        properties = {
          title  = "Status do Alarme (EC2 Health)"
          alarms = [aws_cloudwatch_metric_alarm.ec2_health_alarm.arn]
        }
      },
      {
        type   = "text"
        x      = 18
        y      = 6
        width  = 6
        height = 6
        properties = {
          markdown = "## Arquitetura AWS TCC\n- **VPC:** `10.0.1.0/24` (`us-east-1`)\n- **Gateway EC2:** `10.0.1.10` (`t3.micro`)\n- **VPN:** StrongSwan IKEv2 (AES-256 / SHA-256)\n- **Failover:** `right=%any` + DPD (FortiGate HA)\n- **Zero Trust:** SSH (VLAN 10) | IoT Web (VLAN 40)"
        }
      },

      # --- LINHA 3: MONITORAMENTO DO TÚNEL IPSEC ---
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["TCC/VPN", "TunnelStatus", "InstanceId", aws_instance.server.id, { label = "Túnel IPsec (1 = UP | 0 = DOWN)" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          period  = 60
          stat    = "Minimum"
          yAxis = {
            left = {
              min = 0
              max = 1
            }
          }
          title = "Disponibilidade do Túnel VPN IPsec (Histórico)"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 6
        height = 6
        properties = {
          metrics = [
            ["TCC/VPN", "TunnelStatus", "InstanceId", aws_instance.server.id, { label = "1 = UP (Ativo) | 0 = DOWN" }]
          ]
          view   = "singleValue"
          region = "us-east-1"
          period = 60
          stat   = "Minimum"
          title  = "Estado Túnel IPsec"
        }
      },
      {
        type   = "alarm"
        x      = 18
        y      = 12
        width  = 6
        height = 6
        properties = {
          title  = "Status do Alarme (Túnel VPN)"
          alarms = [aws_cloudwatch_metric_alarm.vpn_tunnel_alarm.arn]
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

# 3. Alarme de Disponibilidade do Túnel IPsec (Dispara se TunnelStatus < 1)
resource "aws_cloudwatch_metric_alarm" "vpn_tunnel_alarm" {
  alarm_name          = "Status-Tunel-IPsec-AWS"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "TunnelStatus"
  namespace           = "TCC/VPN"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  treat_missing_data  = "breaching"
  alarm_description   = "Alerta se o tunel VPN IPsec IKEv2 entre FortiGate e AWS cair (0 = DOWN)"

  dimensions = {
    InstanceId = aws_instance.server.id
  }

  tags = {
    Name = "Alarme-Tunel-IPsec-AWS"
  }
}

# 4. VPC Flow Logs para Auditoria Zero Trust via Amazon S3 (Compatível com AWS Academy)

resource "aws_flow_log" "tcc_vpc_flow_log" {
  log_destination = "arn:aws:s3:::tcc-netryon-flow-logs-20261118125612525800000001"
  log_destination_type     = "s3"
  traffic_type             = "ALL"
  vpc_id                   = aws_vpc.main.id
  max_aggregation_interval = 60

  tags = {
    Name = "FlowLogs-VPC-TCC"
  }
}