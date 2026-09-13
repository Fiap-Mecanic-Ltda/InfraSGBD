# InfraSGBD — Infraestrutura do Banco de Dados Gerenciado

Terraform do **RDS SQL Server** do projeto MechanicLtda: instância, subnet group, security group
e a connection string publicada no SSM Parameter Store.

## Os quatro repositórios do projeto

| # | Repositório | Conteúdo | CI/CD |
|---|---|---|---|
| 1 | [Lambda](https://github.com/Fiap-Mecanic-Ltda/Lambda) | Function serverless de autenticação (API Gateway + Lambda) | build, testes e deploy da função |
| 2 | [InfraKubernete](https://github.com/Fiap-Mecanic-Ltda/InfraKubernete) | Terraform do cluster (VPC, EC2/k3s, ASG, ECR, IAM/OIDC) + manifestos `k8s/` | `terraform plan/apply` + deploy no k3s |
| 3 | **InfraSGBD** (este) | Terraform do RDS SQL Server | `terraform plan/apply` |
| 4 | [MechanicLtda](https://github.com/Fiap-Mecanic-Ltda/MechanicLtda) | Aplicação .NET 9 | build, testes e push das imagens no ECR |

## Como este stack conversa com os outros

```text
InfraKubernete (state prod/terraform.tfstate)
   │  outputs: vpc_id, db_subnet_ids, ec2_security_group_id, worker_security_group_id
   ▼  (terraform_remote_state, somente leitura)
InfraSGBD (state prod/sgbd/terraform.tfstate)
   │  cria: db subnet group, SG do RDS, instância RDS
   │  publica: /mechanicltda/prod/db-connection-string (SecureString)
   ▼
aplicação no k3s e Lambda de autenticação leem a connection string do SSM
```

- **Não cria rede**: VPC e subnets pertencem ao repositório 2 — por isso ele precisa estar
  aplicado antes deste.
- **Não conhece a aplicação**: o contrato é o parâmetro do SSM. Quem consome (pods e Lambda) lê
  de lá; nenhuma senha trafega em YAML versionado.
- **A Lambda adiciona a própria regra** de ingresso na porta 1433 do SG do RDS
  (`aws_vpc_security_group_ingress_rule`, no repositório 1). Por isso o SG daqui tem
  `lifecycle { ignore_changes = [ingress] }` — sem isso, todo apply deste stack apagaria aquela
  regra.

## Estrutura

```text
InfraSGBD/
├── infra/
│   ├── versions.tf              # backend S3 (chave prod/sgbd/terraform.tfstate) e provider
│   ├── data.tf                  # terraform_remote_state do InfraKubernete + locals
│   ├── variables.tf             # project/environment e parâmetros do banco
│   ├── rds.tf                   # subnet group, security group e a instância RDS
│   ├── ssm.tf                   # connection string (SecureString) no Parameter Store
│   └── outputs.tf               # endereço do RDS, SG e nome do parâmetro SSM
├── scripts/migrar-state.sh      # move o RDS já existente para este state, sem destruir
└── .github/workflows/terraform.yml
```

## Rodando localmente

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # preencher com valores reais (nunca commitar)
terraform init
terraform plan
terraform apply
```

> A senha em `terraform.tfvars` precisa ser **a mesma** já configurada no RDS existente. Senha
> diferente = o Terraform tenta um `modify-db-instance` e troca a senha do banco em produção.

## Migração: o RDS já existia no repositório de Kubernetes

Antes da separação dos repositórios, o RDS era gerenciado pelo state do InfraKubernete. Para
passar o controle para cá **sem destruir o banco**, importe os recursos aqui e só depois remova-os
do state antigo:

```bash
./scripts/migrar-state.sh ../InfraKubernete
```

O script faz, com confirmação em cada etapa:

1. `terraform import` de `aws_db_subnet_group.main`, `aws_security_group.rds`,
   `aws_db_instance.main` e `aws_ssm_parameter.db_connection_string` neste repositório;
2. um `terraform plan` para conferência — **não pode** aparecer `create`/`destroy` do RDS;
3. `terraform state rm` dos mesmos recursos no InfraKubernete (remove do state, não da AWS).

Enquanto a etapa 3 não roda, os dois states apontam para os mesmos recursos — não rode `apply` no
InfraKubernete nesse intervalo.

Se preferir recriar o banco do zero em vez de importar, basta rodar `terraform apply` aqui e
`terraform apply` lá (o stack de Kubernetes já não declara mais o RDS): o banco antigo é destruído
com os dados, e a aplicação recria o schema no próximo boot (migrations + seed).

## Secrets necessários no repositório GitHub

(Settings → Secrets and variables → Actions)

| Nome | Tipo | Uso |
|---|---|---|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Secret | Chave do `terraform-deployer` (também lê o state remoto do repositório 2) |
| `SA_PASSWORD` | Secret | `TF_VAR_db_master_password` — senha master do RDS |

O Environment `production` precisa existir para o job de `apply`. `db_engine_version` está fixado
no workflow (`15.00.4430.1.v1`), e `aws_region`/`project_name`/`environment` saem dos defaults de
`infra/variables.tf`.

## Fluxo de trabalho no Git

A branch de trabalho é **`homologacao`**; nada é commitado direto na `main` — a `main` recebe
mudanças por Pull Request.

| Branch | O que roda (quando `infra/**` muda) |
|---|---|
| PR para `homologacao` ou `main` | `plan` |
| push em `homologacao` | `plan` — não há ambiente de homologação na AWS |
| push em `main` | `plan` e **`apply` automático** no Environment `production` |

O `apply` manual (`workflow_dispatch`) continua disponível, mas só a partir da `main`. Configure
revisores obrigatórios no Environment `production`: recriar o RDS apaga os dados (este projeto não
guarda snapshot final), e com revisores o apply espera a aprovação depois do `plan` do mesmo run.
