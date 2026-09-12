variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "mechanicltda"
}

variable "environment" {
  type    = string
  default = "prod"
}

# Rede: este stack nao cria VPC nem subnets. Elas vem do stack de Kubernetes,
# lido via terraform_remote_state (data.tf).

variable "kubernetes_state_bucket" {
  type        = string
  description = "Bucket S3 com o state do stack de infraestrutura de Kubernetes."
  default     = "mechanicltda-terraform-state-788516091173"
}

variable "kubernetes_state_key" {
  type        = string
  description = "Chave do state do stack de infraestrutura de Kubernetes dentro do bucket."
  default     = "prod/terraform.tfstate"
}

# RDS

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_engine_version" {
  type        = string
  description = "Versao do engine SQL Server Express (sqlserver-ex)."
}

variable "db_master_username" {
  type        = string
  description = "Usuario master do RDS. Nao pode ser 'sa'."
  default     = "mechanicltda_admin"
}

variable "db_master_password" {
  type        = string
  description = "Senha do usuario master do RDS."
  sensitive   = true
}

variable "db_name" {
  type        = string
  description = "Banco usado pela aplicacao na connection string publicada no SSM."
  default     = "MechanicLtdaDb"
}

variable "db_allocated_storage" {
  type        = number
  description = "Storage do RDS em GiB."
  default     = 20
}

variable "db_backup_retention_period" {
  type    = number
  default = 7
}
