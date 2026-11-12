variable "prefix" {
  description = "Organisation prefix, e.g. 'adv' for Aldervane."
  type        = string
}

variable "environment" {
  description = "Environment short code."
  type        = string

  validation {
    condition     = contains(["dev", "tst", "stg", "prd", "sec", "net", "lgc"], var.environment)
    error_message = "environment must be one of dev, tst, stg, prd, sec, net, lgc."
  }
}

variable "name" {
  description = "Workload/component name, e.g. 'sentinel'."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,18}$", var.name))
    error_message = "name must be 3-19 chars, lowercase letters, digits, hyphens."
  }
}

variable "folder_id" {
  description = "Parent folder, e.g. 'folders/123'."
  type        = string
}

variable "billing_account" {
  description = "Billing account ID (XXXXXX-XXXXXX-XXXXXX)."
  type        = string
}

variable "cost_center" {
  description = "Finance cost centre code (lowercase, label-safe)."
  type        = string
}

variable "data_classification" {
  description = "Highest data class processed in this project."
  type        = string

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be public, internal, confidential or restricted."
  }
}

variable "owner" {
  description = "Owning team (label-safe)."
  type        = string
}

variable "demand_id" {
  description = "Approved demand reference from demand management, e.g. 'dmd-0042'. Projects cannot exist without an approved demand."
  type        = string

  validation {
    condition     = can(regex("^dmd-[0-9]{4,}$", var.demand_id))
    error_message = "demand_id must look like dmd-0042 (an approved demand record)."
  }
}

variable "extra_labels" {
  description = "Additional labels. Mandatory labels always win on conflicts."
  type        = map(string)
  default     = {}
}

variable "apis" {
  description = "APIs to enable."
  type        = list(string)
  default     = []
}

variable "shared_vpc_host_project_id" {
  description = "If set, attach as a Shared VPC service project."
  type        = string
  default     = null
}

variable "security_contacts" {
  description = "Emails for SECURITY/LEGAL essential contacts."
  type        = list(string)
  default     = []
}

variable "monthly_budget_eur" {
  description = "Monthly budget in EUR. 0 disables the budget."
  type        = number
  default     = 0
}
