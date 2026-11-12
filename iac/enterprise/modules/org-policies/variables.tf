variable "parent" {
  description = "Policy parent: 'organizations/123456789' or 'folders/987654321'."
  type        = string

  validation {
    condition     = can(regex("^(organizations|folders)/[0-9]+$", var.parent))
    error_message = "parent must look like organizations/<id> or folders/<id>."
  }
}

variable "allowed_locations" {
  description = "Values for gcp.resourceLocations. Use value groups such as in:eu-locations."
  type        = list(string)
  default     = ["in:eu-locations"]
}

variable "allowed_customer_ids" {
  description = "Cloud Identity customer IDs allowed in IAM policies, e.g. ['is:C0abc123']."
  type        = list(string)
}

variable "cmek_required_services" {
  description = "APIs that must use CMEK (gcp.restrictNonCmekServices)."
  type        = list(string)
  default = [
    "bigquery.googleapis.com",
    "pubsub.googleapis.com",
    "storage.googleapis.com",
    "spanner.googleapis.com",
    "sqladmin.googleapis.com",
    "alloydb.googleapis.com",
    "container.googleapis.com",
    "compute.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
  ]
}

variable "kms_project_ids" {
  description = "Projects allowed to host CMEK keys. Empty = constraint not set."
  type        = list(string)
  default     = []
}

variable "allowed_services" {
  description = "Allow-list for gcp.restrictServiceUsage. Empty = constraint not set."
  type        = list(string)
  default     = []
}
