variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Região da AWS onde os recursos serão criados"
}

variable "company_public_ip" {
  type        = string
  description = "IP Público de saída da rede do SENAI/Firewall"
  default     = "186.251.155.232" # <-- CONFIRME o IP público atual do laboratório
}

# VLAN 10 - TI (Segue o objeto VLAN10_TI do FortiGate)
variable "vlan10_ti_cidr" {
  type        = string
  description = "Bloco de rede (CIDR) da VLAN_10_TI"
  default     = "192.168.10.0/24"
}

# VLAN 20 - Colaboradores (Segue o objeto VLAN20_Colaboradores do FortiGate)
variable "vlan20_colab_cidr" {
  type        = string
  description = "Bloco de rede (CIDR) da VLAN_20_Colab"
  default     = "192.168.20.0/24"
}

# VLAN 30 - DMZ (Segue o objeto VLAN30_DMZ do FortiGate)
variable "vlan30_dmz_cidr" {
  type        = string
  description = "Bloco de rede (CIDR) da VLAN_30_DMZ"
  default     = "192.168.30.0/24"
}

# VLAN 40 - IoT (Segue o objeto VLAN40_IoT do FortiGate)
variable "vlan40_iot_cidr" {
  type        = string
  description = "Bloco de rede (CIDR) da VLAN_40_IoT"
  default     = "192.168.40.0/24"
}