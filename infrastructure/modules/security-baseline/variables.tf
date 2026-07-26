variable "environment" {
  type        = string
  default     = "production"
  description = "Entorno de despliegue"
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "Región principal de AWS"
}

variable "company_name" {
  type        = string
  default     = "fleetsec"
  description = "Nombre de la compañía"
}