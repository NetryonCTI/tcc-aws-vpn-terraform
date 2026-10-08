output "server_private_ip" {
  description = "IP Privado Fixo do Servidor na AWS"
  value       = aws_instance.server.private_ip
}

output "vpn_public_endpoint" {
  description = "IP Público da EC2 para fechar a VPN no Firewall Externo"
  value       = aws_instance.server.public_ip
}