/**
 * Quillpay production: Canadian cell (PIPEDA, RPAA, FINTRAC). See Case 5.
 *
 * Primary northamerica-northeast1 (Montréal); backups in northamerica-northeast2
 * (Toronto). No Canadian personal information is replicated to the EU cell.
 */

terraform {
  required_version = ">= 1.9.0"
  backend "gcs" {
    bucket = "qp-seed-tfstate"
    prefix = "envs/prod-ca"
  }
}

provider "google" {}
provider "google-beta" {}

variable "folder_id" { type = string }
variable "billing_account" { type = string }

module "platform" {
  source = "../../modules/platform"

  environment     = "prod"
  jurisdiction    = "ca"
  region          = "northamerica-northeast1"
  bq_location     = "northamerica-northeast1"
  backup_location = "northamerica-northeast2"
  folder_id       = var.folder_id
  billing_account = var.billing_account
  subnet_cidr     = "10.1.0.0/24"
  sql_tier        = "db-custom-2-7680"
  max_instances   = 20
  monthly_budget  = 4000
  budget_currency = "EUR" # must match the billing account currency

  # PIPEDA: breach records ≥ 24 months. Locked, so not even an org admin can shorten it.
  breach_record_retention_days = 1096
  lock_retention               = true

  labels = {
    privacy_regime = "pipeda"
    quebec_law25   = "in-scope"
  }
}

output "platform" {
  value = module.platform
}
