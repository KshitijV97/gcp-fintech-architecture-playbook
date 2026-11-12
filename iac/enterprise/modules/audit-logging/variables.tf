variable "org_id" {
  type = string
}

variable "logging_project_id" {
  type = string
}

variable "location" {
  description = "Region for the log bucket and archive bucket (must match the KMS key location)."
  type        = string
  default     = "europe-west3"
}

variable "kms_key_id" {
  description = "CMEK key ID for logs (in the same location)."
  type        = string
}

variable "log_bucket_retention_days" {
  description = "Queryable retention. 1827 days ≈ 5 years (AML)."
  type        = number
  default     = 1827
}

variable "archive_retention_days" {
  description = "WORM archive retention. 3653 days ≈ 10 years."
  type        = number
  default     = 3653
}

variable "lock_log_bucket" {
  description = "IRREVERSIBLE. Lock the log bucket retention."
  type        = bool
  default     = false
}

variable "lock_archive_bucket" {
  description = "IRREVERSIBLE. Lock the GCS retention policy."
  type        = bool
  default     = false
}

variable "filter" {
  description = "Which logs to route. Default: all Cloud Audit Logs (Admin Activity, Data Access, System Event, Policy Denied) and Access Transparency, which is logged as cloudaudit.googleapis.com%2Faccess_transparency."
  type        = string
  default     = "logName:\"/logs/cloudaudit.googleapis.com\""
}
