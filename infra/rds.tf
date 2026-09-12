# Subnets privadas (sem rota para a internet) provisionadas pelo stack de
# Kubernetes - aqui elas so viram um subnet group do RDS.
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = local.db_subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "SG do RDS SQL Server, so aceita trafego dos nos k3s"
  vpc_id      = local.vpc_id

  # Inclui o SG dos workers: um pod da API pode ser agendado em qualquer no do
  # cluster, nao so no server. Os ids vem do state do stack de Kubernetes.
  ingress {
    description     = "SQL Server dos nos k3s (server + workers)"
    from_port       = 1433
    to_port         = 1433
    protocol        = "tcp"
    security_groups = local.k3s_node_sgids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  }

  # A Lambda de autenticacao adiciona a propria regra de ingresso neste SG
  # (aws_vpc_security_group_ingress_rule, no repositorio da Lambda) para nao
  # criar dependencia circular entre os dois stacks. Sem o ignore, todo apply
  # daqui removeria aquela regra.
  lifecycle {
    ignore_changes = [ingress]
  }
}

resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-${var.environment}"
  engine         = "sqlserver-ex"
  engine_version = var.db_engine_version
  license_model  = "license-included"

  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"

  # Criptografia em repouso via chave gerenciada padrao da AWS (aws/rds) -
  # suportada pela instance class atual (db.t3.micro). Sem kms_key_id explicito
  # porque nao ha requisito de rotacao/BYOK alem do padrao da AWS.
  storage_encrypted = true

  username = var.db_master_username
  password = var.db_master_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = false
  publicly_accessible = false

  backup_retention_period    = var.db_backup_retention_period
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true

  # Sem protecao contra exclusao nem snapshot final: projeto de estudo.
  deletion_protection = false
  skip_final_snapshot = true

  tags = {
    Name = "${var.project_name}-${var.environment}-sqlserver"
  }
}
