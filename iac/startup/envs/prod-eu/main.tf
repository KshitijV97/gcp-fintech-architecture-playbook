/**
 * Quillpay production: EU cell (GDPR). Region europe-west3 (Frankfurt).
 */

terraform {
  required_version = ">= 1.9.0"
  backend "gcs" {
    bucket = "qp-seed-tfstate"
    prefix = "envs/prod-eu"
  }
}

provider "google" {}
provider "google-beta" {}

variable "folder_id" { type = string }
variable "billing_account" { type = string }

module "platform" {
  source = "../../modules/platform"

  environment     = "prod"
  jurisdiction    = "eu"
  region          = "europe-west3"
  bq_location     = "EU"
  backup_location = "eu"
  folder_id       = var.folder_id
  billing_account = var.billing_account
  sql_tier        = "db-custom-4-16384"
  max_instances   = 50
  monthly_budget  = 9000
  lock_retention  = true
}

output "platform" {
  value = module.platform
}
