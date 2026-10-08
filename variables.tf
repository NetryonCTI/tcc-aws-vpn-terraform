variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Região da AWS onde os recursos serão criados"
}

variable "company_public_ip" {
  type        = string
  description = "IP Público estático do roteador/firewall da empresa"
  default     = "200.200.200.200" # <-- ALTERE para o IP público da empresa
}

# Subnet CIDR da empresa (Depto de TI)
variable "ti_dept_cidr" {
  type        = string
  description = "Bloco de rede (CIDR) da VLAN do Depto de TI"
  default     = "192.168.10.0/24" # <-- ALTERE para o IP da rede de TI
}

# Subnet CIDR da empresa (Rede IoT)
variable "iot_dept_cidr" {
  type        = string
  description = "Bloco de rede (CIDR) da VLAN de IoT"
  default     = "192.168.20.0/24" # <-- ALTERE para o IP da rede IoT
}