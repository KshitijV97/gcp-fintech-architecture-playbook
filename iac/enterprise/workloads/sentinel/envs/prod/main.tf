/**
 * Sentinel: EU production.
 * Applied ONLY by the CAB-gated apply pipeline (change-management/cloudbuild-apply.yaml).
 */

terraform {
  backend "gcs" {
    prefix = "workloads/sentinel/eu-prod"
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
  description = "Outputs from the landing-zone stage (passed in by the pipeline)."
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

  environment       = "prd"
  jurisdiction      = "eu"
  region            = "europe-west3"
  folder_id         = var.landing_zone.folder_id
  billing_account   = var.landing_zone.billing_account
  kms_project_id    = var.landing_zone.kms_project_id
  access_policy_id  = var.landing_zone.access_policy_id
  demand_id         = "dmd-0042"
  security_contacts = ["fraud-platform-oncall@aldervane.example"]

  network = {
    host_project_id  = var.landing_zone.host_project_id
    network_id       = var.landing_zone.network_id
    subnet_id        = var.landing_zone.subnet_id
    subnet_self_link = var.landing_zone.subnet_self_link
  }

  scoring_nodes = {
    machine_type = "c3-standard-8"
    min          = 3
    max          = 30
  }

  ledger_vcpus       = 16
  monthly_budget_eur = 85000

  # CHG0034567: perimeter enforced after 6 weeks of clean dry-run logs.
  enforce_perimeter = true
}
