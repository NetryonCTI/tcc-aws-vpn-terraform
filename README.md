# AWS EC2 IPsec VPN Gateway via StrongSwan (Terraform)

Este repositório contém os códigos de **Infraestrutura como Código (IaC)** desenvolvidos para a implementação e automação de um túnel VPN IPsec de alta disponibilidade e baixo custo entre a **Amazon Web Services (AWS)** e um firewall **FortiGate** corporativo/acadêmico.

O projeto faz parte do trabalho de conclusão de curso (TCC) focado em **Integração de Redes Híbridas e Automação de Infraestrutura**.

---

## 📐 Arquitetura da Solução

* **Provedor Cloud:** AWS (Amazon Web Services)
* **Provisionamento:** Terraform
* **Gateway VPN (AWS):** Instância EC2 (Amazon Linux 2023) executando **StrongSwan**
* **Firewall Remoto:** FortiGate (Physical / VM)
* **Roteamento Interno:** IP Forwarding ativo no Kernel Linux + `source_dest_check = false` no ENI da EC2
* **Segurança & Firewall (AWS):** Security Groups configurados estritamente para IPsec (UDP 500, UDP 4500, IP Protocol 50) e serviços internos (SSH porta 22 e HTTP IoT porta 8080).

---

## 🔒 Parâmetros Criptográficos (IPsec / IKEv2)

Devido às especificidades de licenciamento do ambiente de borda FortiGate, os parâmetros de negociação IKEv2 e IPsec foram padronizados da seguinte forma:

| Parâmetro | Fase 1 (IKE) | Fase 2 (ESP) |
| :--- | :--- | :--- |
| **Versão IKE** | IKEv2 | IKEv2 |
| **Criptografia** | DES | DES |
| **Autenticação / Hash** | SHA-256 | SHA-256 |
| **Grupo Diffie-Hellman** | DH Group 14 (modp2048) | DH Group 14 (modp2048) |
| **Autenticação** | Pre-Shared Key (PSK) | Pre-Shared Key (PSK) |

---

## 🌐 Topologia de Subredes

* **VPC AWS:** `10.0.0.0/16`
* **Subnet Privada AWS:** `10.0.1.0/24`
* **Servidor / Gateway AWS:** `10.0.1.10`
* **Rede TI (On-Premises):** `192.168.10.0/24`
* **Rede IoT (On-Premises):** `192.168.20.0/24`

---

## 🚀 Como Executar este Projeto

### Pré-requisitos
* [Terraform CLI](https://www.terraform.io/downloads) instalado.
* [AWS CLI](https://aws.amazon.com/cli/) configurado com as credenciais de acesso (`aws configure`).

### Passos para Implantação

1. **Clonar o repositório:**
   ```bash
   git clone [https://github.com/NetryonCTI/tcc-aws-vpn-terraform.git](https://github.com/NetryonCTI/tcc-aws-vpn-terraform.git)
   cd tcc-aws-vpn-terraform