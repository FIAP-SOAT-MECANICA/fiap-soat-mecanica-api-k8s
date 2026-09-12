variable "project" {
  type        = string
  description = "Nome do cluster e prefixo dos recursos."
  default     = "mecanica"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.project))
    error_message = "project deve ser um nome DNS valido em letras minusculas."
  }
}

variable "aws_region" {
  type        = string
  description = "Regiao AWS. O Learner Lab permite apenas us-east-1 e us-west-2."
  default     = "us-east-1"
}

variable "lab_role_name" {
  type        = string
  description = "IAM Role pre-existente usada pelo control plane e pelos nodes. No Learner Lab nao e possivel criar roles."
  default     = "LabRole"
}

variable "lab_session_role_name" {
  type        = string
  description = "IAM Role assumida pela sessao do Learner Lab (console, CLI e pipeline). Recebe acesso admin ao cluster."
  default     = "voclabs"
}

variable "kubernetes_version" {
  type        = string
  description = "Versao do Kubernetes. null usa a versao padrao atual do EKS."
  default     = null
}

variable "excluded_availability_zones" {
  type        = list(string)
  description = "AZs onde o EKS nao aceita control plane. us-east-1e e a excecao conhecida."
  default     = ["us-east-1e"]
}

variable "node_instance_type" {
  type        = string
  description = "Tipo de instancia EC2 dos nodes."
  default     = "t3.medium"
}

variable "node_disk_size" {
  type        = number
  description = "Disco dos nodes em GiB."
  default     = 50
}

variable "node_desired_size" {
  type        = number
  default     = 2
  description = "Quantidade inicial de nodes."
}

variable "node_min_size" {
  type        = number
  default     = 1
  description = "Minimo de nodes."
}

variable "node_max_size" {
  type        = number
  default     = 3
  description = "Maximo de nodes."

  validation {
    condition     = var.node_max_size >= var.node_desired_size && var.node_desired_size >= var.node_min_size
    error_message = "Deve valer node_min_size <= node_desired_size <= node_max_size."
  }
}
