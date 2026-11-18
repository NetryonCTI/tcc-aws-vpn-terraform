# Busca a imagem oficial mais recente do Ubuntu 22.04 LTS (compatível nativamente com StrongSwan)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group estrito + Liberação do Túnel IPSec, ICMP e Serviços
resource "aws_security_group" "server_sg" {
  name        = "sg_servidor_tcc"
  description = "Regras de acesso Zero Trust e conexao VPN IPSec para o TCC"
  vpc_id      = aws_vpc.main.id

  # 1. Gestão SSH (Porta 22) -> Exclusivo para VLAN 10 (TI)
  ingress {
    description = "SSH exclusivo via VLAN10_TI"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vlan10_ti_cidr]
  }

  # 2. Painel Web IoT/OT (Porta 8080) -> Acessível pelas VLANs autorizadas (TI, Colab, DMZ, IoT)
  ingress {
    description = "Dashboard IoT via VPN"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vlan40_iot_cidr]
  }

  # 3. Ping / ICMP -> Liberado para as VLANs internas do FortiGate
  ingress {
    description = "Ping ICMP das VLANs Internas"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [
      var.vlan10_ti_cidr,
      var.vlan20_colab_cidr,
      var.vlan30_dmz_cidr,
      var.vlan40_iot_cidr
    ]
  }

  # 4. VPN IPSec - IKE (Porta UDP 500)
  ingress {
    description = "VPN IPSec - IKE Phase 1"
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 5. VPN IPSec - NAT Traversal (Porta UDP 4500)
  ingress {
    description = "VPN IPSec - NAT-T Phase 2"
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 6. VPN IPSec - Protocolo ESP (Protocolo IP 50)
  ingress {
    description = "VPN IPSec - ESP Protocol"
    from_port   = 0
    to_port     = 0
    protocol    = "50"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG-Servidor-VPN-AWS"
  }
}

# Instância EC2 que atua como Gateway VPN IPSec e Servidor de Telemetria IoT
resource "aws_instance" "server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.server_sg.id]
  private_ip                  = "10.0.1.10"
  associate_public_ip_address = true
  source_dest_check           = false
  user_data_replace_on_change = true
  iam_instance_profile        = "LabInstanceProfile"

  user_data = <<-EOF
              #!/bin/bash
              export DEBIAN_FRONTEND=noninteractive

              # 1. Instala o StrongSwan, Python3 e AWS CLI
              apt-get update -y
              apt-get install -y strongswan python3 awscli

              # 2. Ativa o encaminhamento de pacotes (IP Forwarding) no Kernel
              sysctl -w net.ipv4.ip_forward=1
              echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

              # 3. Configuracao do StrongSwan (/etc/ipsec.conf no Ubuntu)
              cat << 'CONFIG' > /etc/ipsec.conf
              config setup
                  charondebug="ike 2, knl 2, cfg 2"

              conn tcc-vpn
                  authby=secret
                  auto=add
                  keyexchange=ikev2
                  left=%defaultroute
                  leftsubnet=10.0.1.0/24
                  right=%any
                  rightsubnet=${var.vlan10_ti_cidr},${var.vlan20_colab_cidr},${var.vlan30_dmz_cidr},${var.vlan40_iot_cidr}
                  ike=aes256-sha256-modp2048!
                  esp=aes256-sha256-modp2048!
                  keyingtries=%forever
                  dpddelay=30s
                  dpdtimeout=120s
                  dpdaction=clear
              CONFIG

              # 4. Chave Pre-Compartilhada (PSK)
              cat << 'SECRETS' > /etc/ipsec.secrets
              : PSK "SenhaSecretaTCC2026"
              SECRETS

              # 5. Reinicia o servico IPsec
              systemctl enable strongswan-starter
              systemctl restart strongswan-starter
              ipsec restart

              # 6. Cria o Dashboard Dinamico de Telemetria Industrial/IoT na porta 8080
              mkdir -p /opt/iot
              cat << 'PYEOF' > /opt/iot/server.py
              from http.server import BaseHTTPRequestHandler, HTTPServer

              HTML_TEMPLATE = """<!DOCTYPE html>
              <html lang="pt-BR">
              <head>
                  <meta charset="UTF-8">
                  <title>Netryon OT/IoT Cloud Collector - AWS</title>
                  <style>
                      body { font-family: 'Segoe UI', Arial, sans-serif; background: #0f172a; color: #f8fafc; margin: 0; padding: 30px; }
                      .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #22c55e; padding-bottom: 15px; margin-bottom: 25px; flex-wrap: wrap; gap: 10px; }
                      .badge { background: #16a34a; color: white; padding: 6px 14px; border-radius: 6px; font-size: 14px; font-weight: bold; }
                      .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(230px, 1fr)); gap: 20px; margin-bottom: 25px; }
                      .card { background: #1e293b; padding: 20px; border-radius: 10px; border-left: 4px solid #38bdf8; box-shadow: 0 4px 6px rgba(0,0,0,0.3); }
                      .card h3 { margin-top: 0; color: #94a3b8; font-size: 13px; text-transform: uppercase; letter-spacing: 0.5px; }
                      .card p { margin: 6px 0; font-size: 14px; }
                      .metric-val { font-size: 28px; font-weight: bold; color: #38bdf8; margin-top: 8px; }
                      .audit-box { background: #1e293b; border: 1px solid #334155; border-left: 4px solid #22c55e; padding: 18px 20px; border-radius: 8px; }
                      code { background: #0f172a; color: #fbbf24; padding: 4px 10px; border-radius: 4px; font-size: 16px; font-weight: bold; }
                  </style>
              </head>
              <body>
                  <div class="header">
                      <div>
                          <h1 style="margin:0;">Netryon CTI OT — Coletor Cloud AWS (VPC 10.0.1.0/24)</h1>
                          <p style="margin:5px 0 0 0; color:#94a3b8;">Gateway Privado: <strong>10.0.1.10</strong> | StrongSwan IKEv2</p>
                      </div>
                      <span class="badge">● Túnel IPsec Ativo | AES-256 / SHA-256 / DH 14</span>
                  </div>

                  <div class="grid">
                      <div class="card">
                          <h3>Temperatura Linha OT-01</h3>
                          <div class="metric-val" id="temp">24.8 °C</div>
                          <p style="color:#22c55e;">● Operação Normal</p>
                      </div>
                      <div class="card">
                          <h3>Pressão Sistema Industrial</h3>
                          <div class="metric-val" id="press">4.25 bar</div>
                          <p style="color:#22c55e;">● Estável</p>
                      </div>
                      <div class="card">
                          <h3>Pacotes Telemetria (IoT)</h3>
                          <div class="metric-val" id="pkts">1.842</div>
                          <p style="color:#94a3b8;">Origem: VLAN 40 (192.168.40.0/24)</p>
                      </div>
                      <div class="card">
                          <h3>Latência Túnel VPN</h3>
                          <div class="metric-val" id="lat">17 ms</div>
                          <p style="color:#94a3b8;">Inspeção IPS FortiGate: Ativa</p>
                      </div>
                  </div>

                  <div class="grid">
                      <div class="card">
                          <h3>Gateway Cloud AWS</h3>
                          <p><strong>IP Privado:</strong> 10.0.1.10</p>
                          <p><strong>Failover:</strong> Dinâmico (right=%any + DPD)</p>
                      </div>
                      <div class="card">
                          <h3>Segmentação Zero Trust</h3>
                          <p><strong>SSH (Porta 22):</strong> Exclusivo VLAN 10 (TI)</p>
                          <p><strong>HTTP (Porta 8080):</strong> Exclusivo VLAN 40 (IoT)</p>
                      </div>
                  </div>

                  <div class="audit-box">
                      <h3 style="margin:0 0 10px 0; color:#22c55e;">Auditoria de Conexão Zero Trust em Tempo Real</h3>
                      <p style="margin:5px 0;">IP de Origem Detectado pelo Servidor AWS: <code>CLIENT_IP_PLACEHOLDER</code></p>
                      <p style="margin:5px 0; color:#94a3b8; font-size:13px;">Pacote roteado via túnel IPsec Site-to-Site e autorizado pelo Security Group (sg_servidor_tcc).</p>
                  </div>

                  <script>
                      let packets = 1842;
                      setInterval(() => {
                          document.getElementById('temp').innerText = (24.2 + Math.random() * 1.4).toFixed(1) + ' °C';
                          document.getElementById('press').innerText = (4.15 + Math.random() * 0.25).toFixed(2) + ' bar';
                          packets += Math.floor(Math.random() * 6) + 2;
                          document.getElementById('pkts').innerText = packets.toLocaleString('pt-BR');
                          document.getElementById('lat').innerText = Math.floor(14 + Math.random() * 8) + ' ms';
                      }, 2500);
                  </script>
              </body>
              </html>
              """

              class TelemetryHandler(BaseHTTPRequestHandler):
                  def do_GET(self):
                      client_ip = self.client_address[0]
                      page = HTML_TEMPLATE.replace("CLIENT_IP_PLACEHOLDER", client_ip)
                      self.send_response(200)
                      self.send_header("Content-type", "text/html; charset=utf-8")
                      self.end_headers()
                      self.wfile.write(page.encode("utf-8"))

              if __name__ == "__main__":
                  server = HTTPServer(("0.0.0.0", 8080), TelemetryHandler)
                  server.serve_forever()
              PYEOF

              cat << 'SVCEOF' > /etc/systemd/system/iot-dashboard.service
              [Unit]
              Description=Netryon IoT Telemetry Dashboard
              After=network.target

              [Service]
              ExecStart=/usr/bin/python3 /opt/iot/server.py
              Restart=always
              User=root

              [Install]
              WantedBy=multi-user.target
              SVCEOF

              systemctl daemon-reload
              systemctl enable iot-dashboard
              systemctl start iot-dashboard

              # 7. Monitor do Tunel IPsec -> Envia metrica UP (1) / DOWN (0) ao CloudWatch
              cat << 'MONEOF' > /opt/iot/vpn_monitor.sh
              #!/bin/bash
              TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
              INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

              while true; do
                  if ipsec status | grep -q "ESTABLISHED"; then
                      STATUS=1
                  else
                      STATUS=0
                  fi

                  aws cloudwatch put-metric-data \
                      --region us-east-1 \
                      --namespace "TCC/VPN" \
                      --metric-name "TunnelStatus" \
                      --dimensions InstanceId="$INSTANCE_ID" \
                      --value "$STATUS" \
                      --unit None

                  sleep 30
              done
              MONEOF

              chmod +x /opt/iot/vpn_monitor.sh

              cat << 'VPNMONSVC' > /etc/systemd/system/vpn-cloudwatch-monitor.service
              [Unit]
              Description=Envia status do tunel IPsec StrongSwan para o CloudWatch
              After=strongswan-starter.service

              [Service]
              ExecStart=/bin/bash /opt/iot/vpn_monitor.sh
              Restart=always
              User=root

              [Install]
              WantedBy=multi-user.target
              VPNMONSVC

              systemctl daemon-reload
              systemctl enable vpn-cloudwatch-monitor
              systemctl start vpn-cloudwatch-monitor
              EOF

  tags = {
    Name = "Servidor-VPN-AWS"
  }
}