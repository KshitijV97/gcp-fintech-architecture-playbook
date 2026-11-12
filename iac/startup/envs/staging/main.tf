/**
 * Quillpay staging: synthetic data only, scales to zero, software keys.
 */

terraform {
  required_version = ">= 1.9.0"
  backend "gcs" {
    bucket = "qp-seed-tfstate"
    prefix = "envs/staging"
  }
}

provider "google" {}
provider "google-beta" {}

variable "folder_id" { type = string }
variable "billing_account" { type = string }

module "platform" {
  source = "../../modules/platform"

  environment     = "staging"
  jurisdiction    = "eu"
  region          = "europe-west3"
  bq_location     = "EU"
  backup_location = "eu"
  folder_id       = var.folder_id
  billing_account = var.billing_account
  sql_tier        = "db-f1-micro"
  max_instances   = 3
  monthly_budget  = 500
  lock_retention  = false
}
