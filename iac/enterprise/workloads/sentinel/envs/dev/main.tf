/**
 * Sentinel: EU development. Synthetic data only (no production personal data
 * in non-prod; enforced by Dataplex/SDP discovery scans and policy).
 */

terraform {
  backend "gcs" {
    prefix = "workloads/sentinel/eu-dev"
  }
}

provider "google" {
  impersonate_service_account = var.terraform_service_account
}

provider "google-beta" {
  impersonate_service_account = var.terraform_service_account
}

variable "terraform_service_account" {
  type = string
}

variable "landing_zone" {
  type = object({
    folder_id        = string
    billing_account  = string
    kms_project_id   = string
    access_policy_id = string
    host_project_id  = string
    network_id       = string
    subnet_id        = string
    subnet_self_link = string
  })
}

module "sentinel" {
  source = "../.."

  environment      = "dev"
  jurisdiction     = "eu"
  region           = "europe-west3"
  folder_id        = var.landing_zone.folder_id
  billing_account  = var.landing_zone.billing_account
  kms_project_id   = var.landing_zone.kms_project_id
  access_policy_id = var.landing_zone.access_policy_id
  demand_id        = "dmd-0042"

  network = {
    host_project_id  = var.landing_zone.host_project_id
    network_id       = var.landing_zone.network_id
    subnet_id        = var.landing_zone.subnet_id
    subnet_self_link = var.landing_zone.subnet_self_link
  }

  scoring_nodes = {
    machine_type = "e2-standard-4"
    min          = 1
    max          = 3
  }

  ledger_vcpus = 2
  kafka_capacity = {
    vcpu       = 3
    memory_gib = 12
  }
  monthly_budget_eur = 6000
  enforce_perimeter  = false # dry-run in dev, so violations are observed first
}
