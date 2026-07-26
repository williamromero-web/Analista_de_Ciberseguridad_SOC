# ------------------------------------------------------------------
# VPC Y REDES (3 Capas en 2 AZs)
# ------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Subredes (Simplificadas para demostración IaC)
resource "aws_subnet" "public_az1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.region}a"
}
resource "aws_subnet" "app_az1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.region}a"
}
resource "aws_subnet" "data_az1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = "${var.region}a"
}
resource "aws_subnet" "data_az2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.22.0/24"
  availability_zone = "${var.region}b"
}

# VPC Flow Logs (Hacia CloudWatch)
resource "aws_flow_log" "vpc_flow_logs" {
  iam_role_arn    = aws_iam_role.config_role.arn # Reutilizado por simplicidad
  log_destination = aws_cloudwatch_log_group.vpc_flow_log_group.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
}
resource "aws_cloudwatch_log_group" "vpc_flow_log_group" {
  name = "/aws/vpc/${var.company_name}-flow-logs"
}

# ------------------------------------------------------------------
# SECURITY GROUPS (Cero 0.0.0.0/0 en puertos de administración)
# ------------------------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name        = "${var.company_name}-alb-sg"
  vpc_id      = aws_vpc.main.id
  description = "Permitir trafico web legitimo"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app_sg" {
  name        = "${var.company_name}-app-sg"
  vpc_id      = aws_vpc.main.id
  description = "Permitir trafico solo desde el ALB"

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
}

# ------------------------------------------------------------------
# RDS POSTGRESQL (Multi-AZ, Cifrado, Backups, Parámetros)
# ------------------------------------------------------------------
resource "aws_db_subnet_group" "data_subnets" {
  name       = "${var.company_name}-data-subnets"
  subnet_ids = [aws_subnet.data_az1.id, aws_subnet.data_az2.id]
}

resource "aws_db_parameter_group" "secure_pg" {
  name   = "${var.company_name}-secure-pg"
  family = "postgres14"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
  parameter {
    name  = "log_connections"
    value = "1"
  }
}

resource "aws_db_instance" "secure_db" {
  identifier                  = "${var.company_name}-db"
  engine                      = "postgres"
  engine_version              = "14"
  instance_class              = "db.t3.micro"
  allocated_storage           = 20
  db_name                     = "fleetsec"
  username                    = "dbadmin"
  manage_master_user_password = true # AWS gestiona la clave en Secrets Manager

  multi_az                = true
  publicly_accessible     = false
  storage_encrypted       = true
  kms_key_id              = aws_kms_key.rds_key.arn
  db_subnet_group_name    = aws_db_subnet_group.data_subnets.name
  parameter_group_name    = aws_db_parameter_group.secure_pg.name
  backup_retention_period = 7
  skip_final_snapshot     = true
}