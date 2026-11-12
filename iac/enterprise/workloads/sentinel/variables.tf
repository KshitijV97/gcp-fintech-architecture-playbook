variable "prefix" {
  type    = string
  default = "adv"
}

variable "environment" {
  type = string
}

variable "jurisdiction" {
  description = "Legal jurisdiction of the data in this deployment (eu | ca). Drives data-governance tags."
  type        = string

  validation {
    condition     = contains(["eu", "ca"], var.jurisdiction)
    error_message = "jurisdiction must be eu or ca."
  }
}

variable "region" {
  type = string
}

variable "folder_id" {
  type = string
}

variable "billing_account" {
  type = string
}

variable "demand_id" {
  description = "Approved demand record that funds this deployment."
  type        = string
}

variable "kms_project_id" {
  type = string
}

variable "access_policy_id" {
  type = string
}

variable "security_contacts" {
  type    = list(string)
  default = []
}

variable "monthly_budget_eur" {
  type    = number
  default = 0
}

variable "network" {
  description = "Shared VPC details from the landing zone outputs."
  type = object({
    host_project_id  = string
    network_id       = string
    subnet_id        = string
    subnet_self_link = string
  })
}

variable "master_cidr" {
  type    = string
  default = "172.16.0.0/28"
}

variable "master_authorized_cidrs" {
  description = "CIDRs allowed to reach the private GKE control plane (CI private pool, admin jump range via IAP)."
  type        = list(string)
  default     = []
}

variable "scoring_nodes" {
  type = object({
    machine_type = string
    min          = number
    max          = number
  })
  default = {
    machine_type = "c3-standard-8"
    min          = 1
    max          = 10
  }
}

variable "ledger_vcpus" {
  type    = number
  default = 16
}

variable "kafka_capacity" {
  type = object({
    vcpu       = number
    memory_gib = number
  })
  default = {
    vcpu       = 12
    memory_gib = 48
  }
}

variable "kafka_topics" {
  description = "Topics. Raw topics carry tokens only (no direct identifiers) and short retention."
  type = map(object({
    partitions      = number
    retention_hours = number
    cleanup_policy  = optional(string, "delete")
  }))
  default = {
    "payments.raw"     = { partitions = 48, retention_hours = 168 }
    "decisions"        = { partitions = 48, retention_hours = 168 }
    "customer.profile" = { partitions = 24, retention_hours = 8760, cleanup_policy = "compact" }
    "privacy.commands" = { partitions = 6, retention_hours = 720 }
  }
}

variable "perimeter_ingress_identities" {
  type    = list(string)
  default = []
}

variable "enforce_perimeter" {
  type    = bool
  default = false
}
