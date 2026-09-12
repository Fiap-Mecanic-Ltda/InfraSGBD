#!/usr/bin/env bash
# Migra o RDS que ja existe do state do InfraKubernete para o state deste
# repositorio, SEM destruir nada: importa aqui e depois solta la.
#
# Uso:
#   AWS_PROFILE=... ./scripts/migrar-state.sh /caminho/para/InfraKubernete
#
# Pre-requisitos: terraform >= 1.10, aws cli autenticado com a mesma identidade
# usada nos applies (terraform-deployer) e o infra/terraform.tfvars preenchido
# aqui com a senha atual do banco.
set -euo pipefail

K8S_REPO="${1:-}"
if [ -z "$K8S_REPO" ] || [ ! -d "$K8S_REPO/infra" ]; then
  echo "Informe o caminho do repositorio InfraKubernete. Ex.:"
  echo "  $0 ../InfraKubernete"
  exit 1
fi

DB_DIR="$(cd "$(dirname "$0")/../infra" && pwd)"
K8S_DIR="$(cd "$K8S_REPO/infra" && pwd)"

PROJECT="${PROJECT_NAME:-mechanicltda}"
ENVIRONMENT="${ENVIRONMENT:-prod}"
PREFIX="/${PROJECT}/${ENVIRONMENT}"

echo "==> Descobrindo os recursos existentes na AWS"
SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=${PROJECT}-${ENVIRONMENT}-rds-sg" \
  --query "SecurityGroups[0].GroupId" --output text)
if [ -z "$SG_ID" ] || [ "$SG_ID" = "None" ]; then
  echo "Nao encontrei o security group ${PROJECT}-${ENVIRONMENT}-rds-sg." >&2
  exit 1
fi
echo "    security group : $SG_ID"
echo "    db instance    : ${PROJECT}-${ENVIRONMENT}"
echo "    subnet group   : ${PROJECT}-${ENVIRONMENT}-db-subnet-group"
echo "    ssm parameter  : ${PREFIX}/db-connection-string"

read -r -p "Confirma a migracao para o state deste repositorio? [s/N] " ok
[ "$ok" = "s" ] || [ "$ok" = "S" ] || { echo "abortado"; exit 1; }

echo
echo "==> 1/3 Importando no state deste repositorio (nenhum recurso e criado)"
terraform -chdir="$DB_DIR" init -input=false
terraform -chdir="$DB_DIR" import aws_db_subnet_group.main "${PROJECT}-${ENVIRONMENT}-db-subnet-group"
terraform -chdir="$DB_DIR" import aws_security_group.rds "$SG_ID"
terraform -chdir="$DB_DIR" import aws_db_instance.main "${PROJECT}-${ENVIRONMENT}"
terraform -chdir="$DB_DIR" import aws_ssm_parameter.db_connection_string "${PREFIX}/db-connection-string"

echo
echo "==> 2/3 Conferindo: o plan abaixo NAO pode conter create/destroy do RDS"
terraform -chdir="$DB_DIR" plan -input=false

read -r -p "O plan ficou limpo? Seguir para a remocao do state antigo? [s/N] " ok
[ "$ok" = "s" ] || [ "$ok" = "S" ] || { echo "parado antes do state rm - os dois states apontam para os mesmos recursos, nao rode apply no InfraKubernete ate concluir"; exit 1; }

echo
echo "==> 3/3 Soltando os recursos do state do InfraKubernete (nao destroi nada)"
terraform -chdir="$K8S_DIR" init -input=false
terraform -chdir="$K8S_DIR" state rm aws_db_instance.main
terraform -chdir="$K8S_DIR" state rm aws_db_subnet_group.main
terraform -chdir="$K8S_DIR" state rm aws_security_group.rds
terraform -chdir="$K8S_DIR" state rm aws_ssm_parameter.db_connection_string

echo
echo "Pronto. Rode um plan nos dois repositorios: ambos devem ficar sem mudancas."
