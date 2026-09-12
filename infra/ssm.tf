# A connection string e o unico ponto de contato entre este stack e quem
# consome o banco (pods da aplicacao e Lambda de autenticacao): fica no SSM
# Parameter Store como SecureString, no mesmo prefixo dos demais segredos da
# aplicacao (/projeto/ambiente), e nunca em YAML ou variavel de ambiente
# versionada. O deploy do Kubernetes le este parametro a cada rollout.
locals {
  db_connection_string = "Server=${aws_db_instance.main.address},1433;Database=${var.db_name};User Id=${var.db_master_username};Password=${var.db_master_password};TrustServerCertificate=True;"
}

resource "aws_ssm_parameter" "db_connection_string" {
  name  = "${local.ssm_path_prefix}/db-connection-string"
  type  = "SecureString"
  value = local.db_connection_string
}
