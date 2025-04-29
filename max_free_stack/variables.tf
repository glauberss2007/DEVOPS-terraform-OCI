variable "tenancy_ocid" {
  # Define uma variável chamada "tenancy_ocid".  OCID (Oracle Cloud Identifier) é um identificador único para recursos na OCI.  A tenancy é a conta raiz na OCI.
  description = "OCID da tenancy" # Descrição da variável.
  type        = string # Tipo da variável (string).
  nullable    = false # Indica que a variável não pode ser nula (deve ter um valor).
}

variable "region" {
  # Define uma variável chamada "region".
  description = "Região para os recursos" # Descrição da variável.
  type        = string # Tipo da variável (string).
  nullable    = false # Indica que a variável não pode ser nula.
}

variable "name" {
  # Define uma variável chamada "name".
  description = "Nome de exibição (display name) para os recursos" # Descrição da variável.
  type        = string # Tipo da variável (string).
  nullable    = false # Indica que a variável não pode ser nula.
  default     = "OCI Free Compute Maximal" # Define um valor padrão para a variável. Se nenhum valor for fornecido, este valor será usado.
}

variable "cidr_block" {
  # Define uma variável chamada "cidr_block".  CIDR (Classless Inter-Domain Routing) é uma notação para representar um bloco de endereços IP.  É usado para definir o intervalo de endereços IP para a VCN (Virtual Cloud Network).
  description = "Bloco CIDR da VCN" # Descrição da variável.
  type        = string # Tipo da variável (string).
  default     = null # Define o valor padrão como nulo (nenhum valor).

  validation {
    # Define regras de validação para a variável. Isso ajuda a garantir que o valor fornecido seja válido.
    condition = (
      # A condição para a validação.
      var.cidr_block == null ? # Se a variável "cidr_block" for nula...
      true : # ...a validação passa (não há nada para validar).
      alltrue( # Caso contrário, verifica se todas as condições a seguir são verdadeiras.
        [
          can(cidrsubnet(var.cidr_block, 2, 0)), # Verifica se é possível criar uma subnet com o bloco CIDR fornecido. O "can" função verifica se uma expressão é válida.
          cidrhost(var.cidr_block, 0) == split("/", var.cidr_block).0, # Verifica se o primeiro endereço IP no bloco CIDR é igual ao bloco CIDR em si (garante que o bloco CIDR seja válido).
        ]
      )
    )
    error_message = "O valor da variável cidr_block deve ser um endereço CIDR válido com um prefixo não maior que 30." # Mensagem de erro a ser exibida se a validação falhar.
  }
}

variable "ssh_public_key" {
  # Define uma variável chamada "ssh_public_key".
  description = "Chave pública a ser usada para acesso SSH às instâncias de computação" # Descrição da variável.
  type        = string # Tipo da variável (string).
  nullable    = false # Indica que a variável não pode ser nula.
}