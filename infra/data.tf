# A rede (VPC, subnets de banco) e os security groups dos nos k3s pertencem ao
# stack de infraestrutura de Kubernetes. Em vez de duplicar esses recursos ou
# descobrir ids por filtro de tag, este stack le os outputs do state remoto -
# so leitura, nao trava nem grava nada no state do outro repositorio.
data "terraform_remote_state" "kubernetes" {
  backend = "s3"

  config = {
    bucket = var.kubernetes_state_bucket
    key    = var.kubernetes_state_key
    region = var.aws_region
  }
}

locals {
  vpc_id        = data.terraform_remote_state.kubernetes.outputs.vpc_id
  db_subnet_ids = data.terraform_remote_state.kubernetes.outputs.db_subnet_ids
  k3s_node_sgids = [
    data.terraform_remote_state.kubernetes.outputs.ec2_security_group_id,
    data.terraform_remote_state.kubernetes.outputs.worker_security_group_id,
  ]

  ssm_path_prefix = "/${var.project_name}/${var.environment}"
}
