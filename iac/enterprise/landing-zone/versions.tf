terraform {
  required_version = ">= 1.9.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.11"
    }
  }

  # State lives in a CMEK-encrypted, versioned bucket in the seed project.
  # Values are supplied per pipeline with -backend-config.
  backend "gcs" {
    prefix = "landing-zone"
  }
}

provider "google" {
  # The pipeline runs as the landing-zone service account through
  # impersonation. No keys anywhere.
  impersonate_service_account = var.terraform_service_account
  billing_project             = var.seed_project_id
  user_project_override       = true
}
