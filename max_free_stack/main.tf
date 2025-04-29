# Cria um compartimento (compartment) na OCI para organizar os recursos.
resource "oci_identity_compartment" "this" {
  compartment_id = var.tenancy_ocid # OCID (Oracle Cloud Identifier) da tenancy (conta principal da OCI).  Definido em variáveis.
  description    = var.name        # Descrição do compartment. Definido em variáveis.
  name           = replace(var.name, " ", "-") # Nome do compartment, substituindo espaços por hífens. Definido em variáveis.

  enable_delete = true # Permite que o compartimento seja excluído.
}

# Gera um número inteiro aleatório entre 0 e 255.
# Usado para criar um bloco CIDR único para a VCN.
resource "random_integer" "this" {
  min = 0
  max = 255
}

# Cria uma VCN (Virtual Cloud Network) na OCI.
# A VCN é uma rede virtual privada dentro da OCI.
resource "oci_core_vcn" "this" {
  compartment_id = oci_identity_compartment.this.id # Compartment onde a VCN será criada.

  cidr_blocks  = [coalesce(var.cidr_block, "192.168.${random_integer.this.result}.0/24")] # Bloco CIDR para a VCN. Se a variável `cidr_block` estiver definida, usa ela. Caso contrário, gera um bloco CIDR usando o número aleatório.
  display_name = var.name # Nome da VCN. Definido em variáveis.
  dns_label    = "vcn" # Label para o DNS da VCN.
}

# Cria um Internet Gateway para permitir que a VCN se conecte à internet.
resource "oci_core_internet_gateway" "this" {
  compartment_id = oci_identity_compartment.this.id # Compartment onde o Internet Gateway será criado.
  vcn_id         = oci_core_vcn.this.id # VCN à qual o Internet Gateway será associado.

  display_name = oci_core_vcn.this.display_name # Nome do Internet Gateway (o mesmo da VCN).
}

# Modifica a tabela de rotas padrão da VCN para rotear o tráfego para o Internet Gateway.
resource "oci_core_default_route_table" "this" {
  manage_default_resource_id = oci_core_vcn.this.default_route_table_id # OCID da tabela de rotas padrão da VCN.

  display_name = oci_core_vcn.this.display_name # Nome da tabela de rotas (o mesmo da VCN).

  route_rules {
    network_entity_id = oci_core_internet_gateway.this.id # OCID do Internet Gateway.

    description = "Rota padrão" # Descrição da rota.
    destination = "0.0.0.0/0" # Destino da rota (qualquer endereço IP).
  }
}

# Modifica a lista de segurança padrão da VCN para permitir o tráfego SSH (porta 22) e HTTPS (porta 443) de qualquer lugar.
resource "oci_core_default_security_list" "this" {
  manage_default_resource_id = oci_core_vcn.this.default_security_list_id # OCID da lista de segurança padrão da VCN.

  dynamic "ingress_security_rules" {
    for_each = [22, 80, 443] # Portas para as quais serão criadas regras de entrada.
    iterator = port
    content {
      protocol = local.protocol_number.tcp # Protocolo TCP.
      source   = "0.0.0.0/0" # Origem do tráfego (qualquer endereço IP).

      description = "Tráfego SSH e HTTPS de qualquer origem" # Descrição da regra.

      tcp_options {
        max = port.value # Porta máxima.
        min = port.value # Porta mínima.
      }
    }
  }

  egress_security_rules {
    destination = "0.0.0.0/0" # Destino do tráfego (qualquer endereço IP).
    protocol    = "all" # Qualquer protocolo.

    description = "Todo o tráfego para qualquer destino" # Descrição da regra.
  }
}

# Cria uma subnet dentro da VCN.
resource "oci_core_subnet" "this" {
  cidr_block     = oci_core_vcn.this.cidr_blocks.0 # Bloco CIDR da subnet (o primeiro bloco CIDR da VCN).
  compartment_id = oci_identity_compartment.this.id # Compartment onde a subnet será criada.
  vcn_id         = oci_core_vcn.this.id # VCN à qual a subnet pertence.

  display_name = oci_core_vcn.this.display_name # Nome da subnet (o mesmo da VCN).
  dns_label    = "subnet" # Label para o DNS da subnet.
}

# Cria um Network Security Group (NSG) dentro da VCN.
# NSGs fornecem regras de firewall mais granulares do que as Security Lists.
resource "oci_core_network_security_group" "this" {
  compartment_id = oci_identity_compartment.this.id # Compartment onde o NSG será criado.
  vcn_id         = oci_core_vcn.this.id # VCN à qual o NSG pertence.

  display_name = oci_core_vcn.this.display_name # Nome do NSG (o mesmo da VCN).
}

# Cria uma regra de segurança no NSG para permitir o tráfego ICMP (ping) de qualquer lugar.
resource "oci_core_network_security_group_security_rule" "this" {
  direction                 = "INGRESS" # Direção do tráfego (entrada).
  network_security_group_id = oci_core_network_security_group.this.id # OCID do NSG.
  protocol                  = local.protocol_number.icmp # Protocolo ICMP.
  source                    = "0.0.0.0/0" # Origem do tráfego (qualquer endereço IP).
}

# Busca as Availability Domains (domínios de disponibilidade) na tenancy.
data "oci_identity_availability_domains" "this" {
  compartment_id = var.tenancy_ocid # OCID da tenancy.
}

# Seleciona aleatoriamente um Availability Domain da lista.
resource "random_shuffle" "this" {
  input = data.oci_identity_availability_domains.this.availability_domains[*].name # Lista de nomes dos Availability Domains.

  result_count = 1 # Seleciona apenas um Availability Domain.
}

# Busca as Shapes (formatos de máquina virtual) disponíveis em cada Availability Domain.
data "oci_core_shapes" "this" {
  for_each = toset(data.oci_identity_availability_domains.this.availability_domains[*].name) # Itera sobre os nomes dos Availability Domains.

  compartment_id = oci_identity_compartment.this.id # Compartment.

  availability_domain = each.key # Nome do Availability Domain atual.
}

# Gera a configuração Cloud-init para as instâncias.
# Cloud-init é usado para configurar as instâncias durante a inicialização.
data "cloudinit_config" "this" {
  for_each = local.instance # Itera sobre as configurações de instâncias definidas em `locals.tf`.

  part {
    content = yamlencode(each.value.user_data) # Converte os dados do usuário para formato YAML.

    content_type = "text/cloud-config" # Tipo de conteúdo.
  }
}

# Busca as imagens disponíveis na OCI para cada tipo de instância.
data "oci_core_images" "this" {
  for_each = local.instance # Itera sobre as configurações de instâncias definidas em `locals.tf`.

  compartment_id = oci_identity_compartment.this.id # Compartment.

  operating_system = each.value.operating_system # Sistema operacional da instância.
  shape            = each.value.shape # Formato da instância.
  sort_by          = "DISPLAYNAME" # Ordena os resultados por nome.
  sort_order       = "DESC" # Ordena em ordem decrescente.
  state            = "AVAILABLE" # Busca apenas imagens disponíveis.
}

# Cria duas instâncias Ubuntu.
resource "oci_core_instance" "ubuntu" {
  count = 2 # Cria duas instâncias.

  availability_domain = one( # Seleciona um Availability Domain para as instâncias.
    [
      for m in data.oci_core_shapes.this :
      m.availability_domain
      if contains(m.shapes[*].name, local.instance.ubuntu.shape) # Filtra os Availability Domains que suportam o formato especificado para a instância Ubuntu.
    ]
  )
  compartment_id = oci_identity_compartment.this.id # Compartment.
  shape          = local.instance.ubuntu.shape # Formato da instância.

  display_name         = "Ubuntu ${count.index + 1}" # Nome da instância.
  preserve_boot_volume = false # Não preserva o volume de boot ao excluir a instância.

  metadata = {
    ssh_authorized_keys = var.ssh_public_key # Chave pública SSH para acesso à instância. Definido em variáveis.
    user_data           = data.cloudinit_config.this["ubuntu"].rendered # Configuração Cloud-init para a instância.
  }

  agent_config {
    are_all_plugins_disabled = true # Desativa todos os plugins do agente OCI.
    is_management_disabled   = true # Desativa o gerenciamento do agente OCI.
    is_monitoring_disabled   = true # Desativa o monitoramento do agente OCI.
  }

  create_vnic_details {
    display_name   = "Ubuntu ${count.index + 1}" # Nome da VNIC (Virtual Network Interface Card).
    hostname_label = "ubuntu-${count.index + 1}" # Label para o hostname da VNIC.
    nsg_ids        = [oci_core_network_security_group.this.id] # Associa a VNIC ao NSG.
    subnet_id      = oci_core_subnet.this.id # Associa a VNIC à subnet.
  }

  source_details {
    source_id               = data.oci_core_images.this["ubuntu"].images.0.id # OCID da imagem a ser usada para a instância.
    source_type             = "image" # Tipo de fonte (imagem).
    boot_volume_size_in_gbs = 50 # Tamanho do volume de boot em GB.
  }

  lifecycle {
    ignore_changes = [source_details.0.source_id] # Ignora mudanças no OCID da imagem após a criação da instância.
  }
}

# Cria uma instância Oracle Linux.
resource "oci_core_instance" "oracle" {
  availability_domain = random_shuffle.this.result.0 # Seleciona um Availability Domain aleatoriamente.
  compartment_id      = oci_identity_compartment.this.id # Compartment.
  shape               = local.instance.oracle.shape # Formato da instância.

  display_name         = "Oracle Linux" # Nome da instância.
  preserve_boot_volume = false # Não preserva o volume de boot ao excluir a instância.

  metadata = {
    ssh_authorized_keys = var.ssh_public_key # Chave pública SSH para acesso à instância.
    user_data           = data.cloudinit_config.this["oracle"].rendered # Configuração Cloud-init para a instância.
  }

  agent_config {
    are_all_plugins_disabled = true # Desativa todos os plugins do agente OCI.
    is_management_disabled   = true # Desativa o gerenciamento do agente OCI.
    is_monitoring_disabled   = true # Desativa o monitoramento do agente OCI.
  }

  create_vnic_details {
    assign_public_ip = false # Não atribui um endereço IP público à VNIC.
    display_name     = "Oracle Linux" # Nome da VNIC.
    hostname_label   = "oracle-linux" # Label para o hostname da VNIC.
    nsg_ids          = [oci_core_network_security_group.this.id] # Associa a VNIC ao NSG.
    subnet_id        = oci_core_subnet.this.id # Associa a VNIC à subnet.
  }

  shape_config {
    memory_in_gbs = 24 # Quantidade de memória em GB.
    ocpus         = 4 # Número de CPUs.
  }

  source_details {
    source_id               = data.oci_core_images.this["oracle"].images.0.id # OCID da imagem a ser usada para a instância.
    source_type             = "image" # Tipo de fonte (imagem).
    boot_volume_size_in_gbs = 100 # Tamanho do volume de boot em GB.
  }

  lifecycle {
    ignore_changes = [source_details.0.source_id] # Ignora mudanças no OCID da imagem após a criação da instância.
  }
}

# Busca o IP privado da instância Oracle Linux.
data "oci_core_private_ips" "this" {
  ip_address = oci_core_instance.oracle.private_ip # Endereço IP privado da instância Oracle Linux.
  subnet_id  = oci_core_subnet.this.id # Subnet à qual a instância pertence.
}

# Cria um IP público reservado e o associa à instância Oracle Linux.
resource "oci_core_public_ip" "this" {
  compartment_id = oci_identity_compartment.this.id # Compartment.
  lifetime       = "RESERVED" # O IP público será reservado (não liberado automaticamente).

  display_name  = oci_core_instance.oracle.display_name # Nome do IP público (o mesmo da instância Oracle Linux).
  private_ip_id = data.oci_core_private_ips.this.private_ips.0.id # OCID do IP privado da instância Oracle Linux.
}

# Cria uma política de backup de volume.
resource "oci_core_volume_backup_policy" "this" {
  compartment_id = oci_identity_compartment.this.id # Compartment.

  display_name = "Daily" # Nome da política de backup.

  schedules {
    backup_type       = "INCREMENTAL" # Tipo de backup (incremental).
    hour_of_day       = 0 # Hora do dia para o backup (meia-noite).
    offset_type       = "STRUCTURED" # Tipo de offset.
    period            = "ONE_DAY" # Período do backup (diário).
    retention_seconds = 86400 # Tempo de retenção do backup (1 dia = 86400 segundos).
    time_zone         = "REGIONAL_DATA_CENTER_TIME" # Fuso horário.
  }
}

# Associa a política de backup aos volumes de boot das instâncias Ubuntu e Oracle Linux.
resource "oci_core_volume_backup_policy_assignment" "this" {
  count = 3 # Associa a política a 3 volumes (2 instâncias Ubuntu + 1 instância Oracle Linux).

  asset_id = (
    count.index < 2 ? # Se o índice for menor que 2 (instâncias Ubuntu)...
    oci_core_instance.ubuntu[count.index].boot_volume_id : # ...usa o OCID do volume de boot da instância Ubuntu.
    oci_core_instance.oracle.boot_volume_id # Caso contrário, usa o OCID do volume de boot da instância Oracle Linux.
  )
  policy_id = oci_core_volume_backup_policy.this.id # OCID da política de backup.
}