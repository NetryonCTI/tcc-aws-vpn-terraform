# ==============================================================================
# PROPOSTA TEÓRICA / ARQUITETURA DE PRODUÇÃO (VPN GERENCIADA AWS)
# ==============================================================================
# Nota do TCC: Este bloco representa a automação via AWS VPN Gateway (VGW) +
# Customer Gateway (CGW). No ambiente de laboratório AWS Academy/Vocareum, a
# chamada 'ec2:CreateCustomerGateway' é bloqueada por SCP. Por esse motivo,
# a VPN ativa no laboratório é gerenciada via StrongSwan na EC2 (ec2.tf).
# ==============================================================================

/*
resource "aws_customer_gateway" "fortigate_cgw" {
  bgp_asn    = 65000
  ip_address = var.company_public_ip
  type       = "ipsec.1"

  tags = {
    Name = "CGW-FortiGate"
  }
}

resource "aws_vpn_gateway" "aws_vgw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "VGW-AWS"
  }
}

resource "aws_vpn_connection" "fortigate_vpn" {
  vpn_gateway_id      = aws_vpn_gateway.aws_vgw.id
  customer_gateway_id = aws_customer_gateway.fortigate_cgw.id
  type                = "ipsec.1"
  static_routes_only  = true

  tunnel1_ike_versions                 = ["ikev2"]
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

resource "aws_vpn_connection_route" "fortigate_lan_route" {
  destination_cidr_block = var.vlan10_ti_cidr
  vpn_connection_id      = aws_vpn_connection.fortigate_vpn.id
}

resource "aws_vpn_gateway_route_propagation" "vgw_prop" {
  vpn_gateway_id = aws_vpn_gateway.aws_vgw.id
  route_table_id = aws_route_table.private_rt.id
}
*/