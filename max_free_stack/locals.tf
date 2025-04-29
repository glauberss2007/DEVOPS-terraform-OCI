locals {
  # Mapeamento de nomes de protocolos para seus respectivos números.
  # Isso facilita a referência aos números de protocolo em regras de firewall ou configurações de rede.
  protocol_number = {
    icmp   = 1    # Internet Control Message Protocol (usado para ping, por exemplo)
    icmpv6 = 58   # ICMP para IPv6
    tcp    = 6    # Transmission Control Protocol (usado para HTTP, SSH, etc.)
    udp    = 17   # User Datagram Protocol (usado para DNS, streaming de vídeo, etc.)
  }

  # Definições para diferentes tipos de instâncias (máquinas virtuais).
  # Permite definir configurações específicas para cada tipo de instância, como o tamanho da máquina, sistema operacional e scripts de inicialização.
  instance = {
    # Configuração para uma instância Ubuntu.
    ubuntu = {
      shape : "VM.Standard.E2.1.Micro",  # Tamanho/formato da instância (tipo de máquina virtual). "VM.Standard.E2.1.Micro" é um tamanho pequeno e gratuito na Oracle Cloud.
      operating_system = "Canonical Ubuntu", # Sistema operacional a ser usado.
      user_data : {
        # Scripts a serem executados durante a inicialização da instância.
        runcmd : ["apt-get remove --quiet --assume-yes --purge apparmor"], # Remove o AppArmor (um módulo de segurança) para simplificar a configuração (cuidado, pode reduzir a segurança).
      },
    },
    # Configuração para uma instância Oracle Linux.
    oracle = {
      shape : "VM.Standard.A1.Flex",  # Formato da instância. "VM.Standard.A1.Flex" é um tipo de máquina virtual ARM flexível na Oracle Cloud.
      operating_system : "Oracle Linux", # Sistema operacional.
      user_data : {
        # Scripts de inicialização.
        runcmd : ["grubby --args selinux=0 --update-kernel ALL"], # Desativa o SELinux (outro módulo de segurança) para simplificar a configuração (cuidado, pode reduzir a segurança).
      },
    },
  }
}