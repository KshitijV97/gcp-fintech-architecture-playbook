variable "access_policy_id" {
  description = "Numeric Access Context Manager policy ID."
  type        = string
}

variable "name" {
  description = "Perimeter name (letters, digits, underscores)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,49}$", var.name))
    error_message = "Perimeter name must start with a letter and contain only letters, digits, underscores."
  }
}

variable "project_numbers" {
  description = "Project NUMBERS (not IDs) inside the perimeter."
  type        = list(string)
}

variable "restricted_services" {
  description = "Google APIs protected by the perimeter."
  type        = list(string)
  default = [
    "bigquery.googleapis.com",
    "storage.googleapis.com",
    "pubsub.googleapis.com",
    "spanner.googleapis.com",
    "alloydb.googleapis.com",
    "sqladmin.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudkms.googleapis.com",
    "secretmanager.googleapis.com",
    "logging.googleapis.com",
    "aiplatform.googleapis.com",
    "dataflow.googleapis.com",
    "managedkafka.googleapis.com",
    "redis.googleapis.com",
    "dlp.googleapis.com",
  ]
}

variable "access_levels" {
  description = "Access level names allowed into the perimeter (e.g. corporate egress IPs)."
  type        = list(string)
  default     = []
}

variable "ingress_identities" {
  description = "Identities (e.g. the CI/CD service account) allowed to call APIs from outside the perimeter. Keep this list tiny."
  type        = list(string)
  default     = []
}

variable "enforce" {
  description = "false = dry-run (log only). true = enforced. Changing to true is a Normal change requiring CAB approval."
  type        = bool
  default     = false
}
