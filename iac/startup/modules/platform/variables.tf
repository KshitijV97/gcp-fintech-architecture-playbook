variable "prefix" {
  type    = string
  default = "qp"
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "environment must be staging or prod."
  }
}

variable "jurisdiction" {
  description = "eu (GDPR cell) or ca (PIPEDA cell)."
  type        = string

  validation {
    condition     = contains(["eu", "ca"], var.jurisdiction)
    error_message = "jurisdiction must be eu or ca."
  }
}

variable "region" {
  type = string
}

variable "bq_location" {
  description = "BigQuery location: EU multi-region, or a Canadian region."
  type        = string
}

variable "backup_location" {
  description = "Cloud SQL backup location: must stay in-jurisdiction (e.g. 'eu', 'northamerica-northeast2')."
  type        = string
}

variable "folder_id" {
  type = string
}

variable "billing_account" {
  type = string
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.0.0/24"
}

variable "sql_tier" {
  type    = string
  default = "db-custom-2-7680"
}

variable "scoring_image" {
  description = "Container image; a placeholder until the app pipeline publishes the real one."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "max_instances" {
  type    = number
  default = 20
}

variable "breach_record_retention_days" {
  description = "≥ 730 days (PIPEDA 24 months). Default 1096 days = 3 years."
  type        = number
  default     = 1096

  validation {
    condition     = var.breach_record_retention_days >= 730
    error_message = "PIPEDA requires breach records to be kept for at least 24 months."
  }
}

variable "lock_retention" {
  description = "IRREVERSIBLE retention lock on the breach-records bucket. true in prod."
  type        = bool
  default     = false
}

variable "monthly_budget" {
  type    = number
  default = 2000
}

variable "budget_currency" {
  type    = string
  default = "EUR"
}

variable "labels" {
  type    = map(string)
  default = {}
}
