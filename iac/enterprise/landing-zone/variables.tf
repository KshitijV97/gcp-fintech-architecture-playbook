variable "org_id" {
  description = "Numeric organization ID."
  type        = string
}

variable "billing_account" {
  type = string
}

variable "seed_project_id" {
  description = "Bootstrap project that holds Terraform state and the CI service account."
  type        = string
}

variable "terraform_service_account" {
  description = "Service account the pipeline impersonates."
  type        = string
}

variable "prefix" {
  type    = string
  default = "adv"
}

variable "customer_id" {
  description = "Cloud Identity customer ID (without 'is:'), e.g. C0abc123."
  type        = string
}

variable "eu_primary_region" {
  type    = string
  default = "europe-west3"
}

variable "ca_primary_region" {
  description = "Primary region for the Canadian data cell (PIPEDA / OSFI)."
  type        = string
  default     = "northamerica-northeast1" # Montréal
}

variable "access_policy_id" {
  description = "Existing Access Context Manager policy ID (there is only one org-level policy)."
  type        = string
}

variable "security_contacts" {
  type = list(string)
}

variable "enable_assured_workloads" {
  description = "Create Assured Workloads folders (EU Regions and Support; Canada Regions and Support)."
  type        = bool
  default     = true
}

variable "lock_audit_buckets" {
  description = "IRREVERSIBLE retention lock on audit buckets. true in production orgs only."
  type        = bool
  default     = false
}

variable "approved_services" {
  description = "Service allow-list maintained by demand management (see demand-management/approved-services.yaml)."
  type        = list(string)
  default     = []
}
