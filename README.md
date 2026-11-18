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

## Observabilidade e Coletor IoT

### 1. Dashboard de Telemetria OT/IoT (Porta 8080)
- **Aplicação:** Servidor HTTP dinâmico em Python (`systemd` service `iot-dashboard`) provisionado via `user_data`.
- **Funcionalidades:** Exibe métricas industriais simuladas em tempo real e realiza a auditoria do **IP de origem da requisição**, comprovando que o tráfego foi roteado pelo túnel VPN IPsec a partir da **VLAN 40 (IoT)**.
- **Controle de Acesso (Zero Trust):** Restrito exclusivamente à sub-rede `192.168.40.0/24` via Security Group (`sg_servidor_tcc`).

### 2. Monitorização via Amazon CloudWatch (`monitoring.tf`)
Toda a camada de observabilidade é provisionada como código (IaC):
- **Dashboard (`TCC-Netryon-AWS-VPN`):**
  - Tráfego de rede em Bytes (`NetworkIn` / `NetworkOut`) e Pacotes (`NetworkPacketsIn` / `NetworkPacketsOut`).
  - Utilização de CPU (`CPUUtilization`) e verificação de integridade (`StatusCheckFailed`).
  - Resumo documental da arquitetura em Markdown integrado ao painel.
- **Alarme (`Saude-Gateway-VPN-AWS`):** Monitora falhas de integridade da instância EC2 (`StatusCheckFailed > 0`).