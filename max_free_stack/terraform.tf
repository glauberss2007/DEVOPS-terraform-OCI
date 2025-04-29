terraform {
  # Configurações relacionadas ao Terraform em si.
  required_providers {
    # Define os provedores (providers) Terraform necessários para este projeto.
    oci = {
      # Configurações para o provedor "oci" (Oracle Cloud Infrastructure).
      source  = "oracle/oci" # Especifica a origem do provedor (namespace/nome).  Isso indica que o provedor é mantido pela Oracle.
      version = "~> 6.20.0" # Restrição de versão para o provedor. "~>" significa "compatível com 6.20.x", mas não compatível com 7.0.0 ou superior. Isso ajuda a garantir a compatibilidade e evitar problemas com mudanças no provedor.
    }
  }
}

provider "oci" {
  # Configura o provedor "oci". Isso é necessário para que o Terraform possa interagir com a Oracle Cloud Infrastructure.
  region = var.region # Define a região da OCI que será usada. O valor é obtido da variável "region".  É importante configurar a região correta para que os recursos sejam criados no local desejado.
}