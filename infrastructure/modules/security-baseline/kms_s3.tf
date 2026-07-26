# ------------------------------------------------------------------
# KMS KEYS (CMK dedicada por servicio)
# ------------------------------------------------------------------

# CMK para S3
resource "aws_kms_key" "s3_key" {
  description             = "CMK para cifrado de buckets S3 FleetSec"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableIAMUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

# CMK para RDS
resource "aws_kms_key" "rds_key" {
  description             = "CMK para cifrado de RDS FleetSec"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableIAMUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

# ------------------------------------------------------------------
# S3 LOGS BUCKET CON OBJECT LOCK COMPLIANCE
# ------------------------------------------------------------------

#checkov:skip=CKV2_AWS_62: "No requerimos notificaciones de eventos (SNS/SQS) para este bucket de auditoria, fuera del alcance."
#checkov:skip=CKV_AWS_18: "No requerimos access logging en el propio bucket de logs por el momento."
#checkov:skip=CKV_AWS_144: "Cross-region replication no requerido para este bucket."
#checkov:skip=CKV2_AWS_61: "Lifecycle de versiones no requerido."
resource "aws_s3_bucket" "audit_logs" {
  bucket              = "${var.company_name}-${var.environment}-audit-logs-${data.aws_caller_identity.current.account_id}"
  object_lock_enabled = true
}

resource "aws_s3_bucket_object_lock_configuration" "audit_logs_lock" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = 365
    }
  }
}

resource "aws_s3_bucket_public_access_block" "audit_logs_block_public" {
  bucket                  = aws_s3_bucket.audit_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit_logs_crypto" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "audit_logs_lifecycle" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    id     = "glacier_archive"
    status = "Enabled"

    filter {} 

    transition {
      days          = 180
      storage_class = "GLACIER"
    }

    # Solución al error CKV_AWS_300
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}