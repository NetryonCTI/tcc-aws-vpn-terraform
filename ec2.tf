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
    cidr_blocks = [
      var.vlan10_ti_cidr,
      var.vlan20_colab_cidr,
      var.vlan30_dmz_cidr,
      var.vlan40_iot_cidr
    ]
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

  user_data = <<-EOF
              #!/bin/bash
              export DEBIAN_FRONTEND=noninteractive

              # 1. Instala o StrongSwan e Python3 rapidamente
              apt-get update -y
              apt-get install -y strongswan python3

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

              # 6. Cria o Dashboard de Telemetria Industrial/IoT na porta 8080
              mkdir -p /opt/iot
              cat << 'HTML' > /opt/iot/index.html
              <!DOCTYPE html>
              <html lang="pt-BR">
              <head>
                  <meta charset="UTF-8">
                  <title>Netryon OT/IoT Cloud Collector - AWS</title>
                  <style>
                      body { font-family: Arial, sans-serif; background: #0f172a; color: #f8fafc; margin: 0; padding: 30px; }
                      .header { border-bottom: 2px solid #22c55e; padding-bottom: 15px; margin-bottom: 25px; }
                      .badge { background: #16a34a; color: white; padding: 5px 12px; border-radius: 6px; font-size: 14px; }
                      .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; }
                      .card { background: #1e293b; padding: 20px; border-radius: 10px; border-left: 4px solid #38bdf8; }
                      .card h3 { margin-top: 0; color: #38bdf8; }
                  </style>
              </head>
              <body>
                  <div class="header">
                      <h1>Netryon CTI OT — Coletor Cloud AWS (VPC 10.0.1.0/24)</h1>
                      <span class="badge">Túnel IPsec IKEv2 Ativo | AES-256 / SHA-256 / DH 14</span>
                  </div>
                  <div class="grid">
                      <div class="card">
                          <h3>Gateway Cloud AWS</h3>
                          <p><strong>IP Privado:</strong> 10.0.1.10</p>
                          <p><strong>Serviço:</strong> StrongSwan IKEv2</p>
                      </div>
                      <div class="card">
                          <h3>Telemetria VLAN 40 (IoT)</h3>
                          <p><strong>Sub-rede:</strong> 192.168.40.0/24</p>
                          <p><strong>Inspeção IPS FortiGate:</strong> Ativa</p>
                      </div>
                      <div class="card">
                          <h3>Segmentação Zero Trust</h3>
                          <p><strong>SSH (Porta 22):</strong> Exclusivo VLAN 10 (TI)</p>
                          <p><strong>HTTP (Porta 8080):</strong> VLANs Autorizadas</p>
                      </div>
                  </div>
              </body>
              </html>
              HTML

              nohup python3 -m http.server 8080 --directory /opt/iot > /var/log/iot_http.log 2>&1 &
              EOF

  tags = {
    Name = "Servidor-VPN-AWS"
  }
}