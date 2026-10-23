output "server_private_ip" {
  description = "IP Privado Fixo do Servidor na AWS"
  value       = aws_instance.server.private_ip
}

output "vpn_public_endpoint" {
  description = "IP Público da EC2 para fechar a VPN no Firewall Externo"
  value       = aws_instance.server.public_ip
}

output "fortigate_cli_update_ip" {
  description = "Comando pronto para atualizar o IP da AWS no FortiGate"
  value       = "config vpn ipsec phase1-interface\n    edit \"vpn-aws-ec2\"\n        set remote-gw ${aws_instance.server.public_ip}\n    next\nend"
}