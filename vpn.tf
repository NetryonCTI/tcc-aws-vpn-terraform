# 1. Customer Gateway (Representa o FortiGate na AWS)
resource "aws_customer_gateway" "fortigate_cgw" {
  bgp_asn    = 65000
  ip_address = var.fortigate_public_ip
  type       = "ipsec.1"

  tags = {
    Name = "CGW-FortiGate"
  }
}

# 2. Virtual Private Gateway (VPN Gateway na AWS)
resource "aws_vpn_gateway" "aws_vgw" {
  vpc_id = var.vpc_id

  tags = {
    Name = "VGW-AWS"
  }
}

# 3. Conexão VPN Site-to-Site IPsec
resource "aws_vpn_connection" "fortigate_vpn" {
  vpn_gateway_id      = aws_vpn_gateway.aws_vgw.id
  customer_gateway_id = aws_customer_gateway.fortigate_cgw.id
  type                = "ipsec.1"
  static_routes_only  = true

  tunnel1_preshared_key           = var.vpn_psk
  tunnel1_ike_versions            = ["ikev1", "ikev2"]
  tunnel1_phase1_encryption_algorithms = ["AES256"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase1_dh_group_numbers      = [14]
  tunnel1_phase2_encryption_algorithms = ["AES256"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase2_dh_group_numbers      = [14]

  tags = {
    Name = "VPN-FortiGate-AWS"
  }
}

# 4. Rota para a rede local do FortiGate
resource "aws_vpn_connection_route" "fortigate_lan_route" {
  destination_cidr_block = var.onprem_lan_cidr # 192.168.10.0/24
  vpn_connection_id      = aws_vpn_connection.fortigate_vpn.id
}

# 5. Propagação de rota na tabela de roteamento da VPC
resource "aws_vpn_gateway_route_propagation" "vgw_prop" {
  vpn_gateway_id = aws_vpn_gateway.aws_vgw.id
  route_table_id = var.route_table_id
}