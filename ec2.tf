# Busca a imagem mais recente do Amazon Linux 2023
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Security Group estrito + Liberação do Túnel IPSec
resource "aws_security_group" "server_sg" {
  name        = "sg_servidor_tcc"
  description = "Regras de acesso e conexao VPN IPSec para o TCC"
  vpc_id      = aws_vpc.main.id

  # 1. Gerenciamento SSH (Porta 22) -> Apenas Depto de TI
  ingress {
    description = "SSH via Depto de TI"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ti_dept_cidr]
  }

  # 2. Serviço IoT (Porta 8080) -> Apenas Rede IoT
  ingress {
    description = "Servico IoT"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.iot_dept_cidr]
  }

  # 3. VPN IPSec - IKE (Porta UDP 500)
  ingress {
    description = "VPN IPSec - IKE Phase 1"
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = ["${var.company_public_ip}/32"]
  }

  # 4. VPN IPSec - NAT Traversal (Porta UDP 4500)
  ingress {
    description = "VPN IPSec - NAT-T Phase 2"
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = ["${var.company_public_ip}/32"]
  }

  # 5. VPN IPSec - Protocolo ESP (Protocolo IP 50)
  ingress {
    description = "VPN IPSec - ESP Protocol"
    from_port   = 0
    to_port     = 0
    protocol    = "50"
    cidr_blocks = ["${var.company_public_ip}/32"]
  }

  # Tráfego de saída totalmente liberado
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

# Instância EC2 que funciona como Servidor e Gateway VPN IPSec
resource "aws_instance" "server" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.server_sg.id]
  private_ip                  = "10.0.1.10"
  associate_public_ip_address = true # IP Público para o firewall/roteador externo conectar

  # DESATIVA A VERIFICAÇÃO DE ORIGEM/DESTINO PARA PERMITIR ROTEAMENTO DA VPN
  source_dest_check           = false

  user_data = <<-EOF
              #!/bin/bash
              # 1. Atualiza e instala o servidor VPN StrongSwan e servidor HTTP Python
              dnf update -y
              dnf install -y strongswan python3

              # 2. Habilita o roteamento de pacotes (IP Forwarding) no Kernel Linux
              sysctl -w net.ipv4.ip_forward=1
              echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

              # 3. Criacao da configuracao do StrongSwan (/etc/strongswan/ipsec.conf)
              cat << 'CONFIG' > /etc/strongswan/ipsec.conf
              config setup
                  charondebug="ike 2, knl 2, cfg 2"

              conn tcc-vpn
                  authby=secret
                  auto=add
                  keyexchange=ikev2
                  left=%defaultroute
                  leftsubnet=10.0.1.0/24
                  right=${var.company_public_ip}
                  rightsubnet=192.168.10.0/24,192.168.20.0/24
                  ike=des-sha256-modp2048!
                  esp=des-sha256!
              CONFIG

              # 4. Definicao da Nova Chave Pre-Compartilhada (PSK)
              cat << 'SECRETS' > /etc/strongswan/ipsec.secrets
              : PSK "SenhaSecretaTCC2026"
              SECRETS

              # 5. Ativa e inicia o servico de VPN
              systemctl enable strongswan
              systemctl restart strongswan

              # 6. Inicia o servico HTTP simulado na porta 8080
              echo "Servico de IoT Ativo na AWS via VPN IPSec" > index.html
              python3 -m http.server 8080 &
              EOF

  tags = {
    Name = "Servidor-VPN-AWS"
  }
}