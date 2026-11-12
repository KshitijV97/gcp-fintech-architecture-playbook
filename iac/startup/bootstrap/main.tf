/**
 * Quillpay bootstrap: run ONCE by a founder or admin, locally, with
 * `gcloud auth application-default login`. After this, every change goes
 * through GitHub Actions with keyless (OIDC) authentication.
 *
 * Creates:
 *   - folders: staging, prod-eu, prod-ca
 *   - lean org guardrails (the 80/20 of the enterprise set)
 *   - seed project with a versioned, CMEK-encrypted Terraform state bucket
 *   - Terraform service account + GitHub Workload Identity Federation
 */

terraform {
  required_version = ">= 1.9.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.11"
    }
  }
  # After the first apply, migrate state into the bucket created here:
  # backend "gcs" { bucket = "qp-seed-tfstate" prefix = "bootstrap" }
}

variable "org_id" { type = string }
variable "billing_account" { type = string }
variable "customer_id" { type = string }
variable "github_repo" {
  description = "owner/repo allowed to deploy, e.g. quillpay/platform"
  type        = string
}

locals {
  org = "organizations/${var.org_id}"
}

# --- Folders -------------------------------------------------------------------

resource "google_folder" "env" {
  for_each     = toset(["staging", "prod-eu", "prod-ca"])
  display_name = each.value
  parent       = local.org
}

# --- Lean guardrails -------------------------------------------------------------

resource "google_org_policy_policy" "bool" {
  for_each = toset([
    "iam.disableServiceAccountKeyCreation",
    "iam.automaticIamGrantsForDefaultServiceAccounts",
    "storage.uniformBucketLevelAccess",
    "storage.publicAccessPrevention",
    "sql.restrictPublicIp",
    "compute.skipDefaultNetworkCreation",
    "compute.requireOsLogin",
  ])
  name   = "${local.org}/policies/${each.value}"
  parent = local.org
  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

resource "google_org_policy_policy" "member_domains" {
  name   = "${local.org}/policies/iam.allowedPolicyMemberDomains"
  parent = local.org
  spec {
    rules {
      values {
        allowed_values = ["is:${var.customer_id}"]
      }
    }
  }
}

resource "google_org_policy_policy" "vm_external_ip" {
  name   = "${local.org}/policies/compute.vmExternalIpAccess"
  parent = local.org
  spec {
    rules {
      deny_all = "TRUE"
    }
  }
}

# Residency per folder: the EU cell stays in the EU, the Canadian cell stays in Canada.
resource "google_org_policy_policy" "locations" {
  for_each = {
    "staging" = ["in:eu-locations"]
    "prod-eu" = ["in:eu-locations"]
    "prod-ca" = ["in:northamerica-northeast1-locations", "in:northamerica-northeast2-locations"]
  }
  name   = "${google_folder.env[each.key].name}/policies/gcp.resourceLocations"
  parent = google_folder.env[each.key].name
  spec {
    rules {
      values {
        allowed_values = each.value
      }
    }
  }
}

# --- Seed project + state bucket ---------------------------------------------------

resource "google_project" "seed" {
  name                = "qp-seed"
  project_id          = "qp-seed"
  org_id              = var.org_id
  billing_account     = var.billing_account
  auto_create_network = false
  deletion_policy     = "PREVENT"
  labels              = { purpose = "terraform-seed" }
}

resource "google_project_service" "seed" {
  for_each = toset([
    "cloudkms.googleapis.com", "iam.googleapis.com", "iamcredentials.googleapis.com",
    "sts.googleapis.com", "cloudresourcemanager.googleapis.com", "cloudbilling.googleapis.com",
    "orgpolicy.googleapis.com", "serviceusage.googleapis.com", "storage.googleapis.com",
    "billingbudgets.googleapis.com",
  ])
  project            = google_project.seed.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_kms_key_ring" "state" {
  project    = google_project.seed.project_id
  name       = "kr-tfstate"
  location   = "europe-west3"
  depends_on = [google_project_service.seed]
}

resource "google_kms_crypto_key" "state" {
  name            = "key-tfstate"
  key_ring        = google_kms_key_ring.state.id
  rotation_period = "7776000s"
  lifecycle {
    prevent_destroy = true
  }
}

data "google_storage_project_service_account" "seed" {
  project    = google_project.seed.project_id
  depends_on = [google_project_service.seed]
}

resource "google_kms_crypto_key_iam_member" "state_gcs" {
  crypto_key_id = google_kms_crypto_key.state.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.seed.email_address}"
}

resource "google_storage_bucket" "state" {
  project                     = google_project.seed.project_id
  name                        = "qp-seed-tfstate"
  location                    = "europe-west3"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.state.id
  }

  depends_on = [google_kms_crypto_key_iam_member.state_gcs]
}

# --- Terraform identity + keyless GitHub federation ----------------------------------

resource "google_service_account" "terraform" {
  project      = google_project.seed.project_id
  account_id   = "sa-terraform"
  display_name = "Terraform (GitHub Actions)"
}

resource "google_organization_iam_member" "terraform" {
  for_each = toset([
    "roles/resourcemanager.folderAdmin",
    "roles/resourcemanager.projectCreator",
    "roles/billing.user",
    "roles/orgpolicy.policyAdmin",
    "roles/iam.securityAdmin",
    "roles/compute.xpnAdmin",
  ])
  org_id = var.org_id
  role   = each.value
  member = google_service_account.terraform.member
}

resource "google_storage_bucket_iam_member" "terraform_state" {
  bucket = google_storage_bucket.state.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.terraform.member
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = google_project.seed.project_id
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
  depends_on                = [google_project_service.seed]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = google_project.seed.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"        = "assertion.sub"
    "attribute.repository"  = "assertion.repository"
    "attribute.ref"         = "assertion.ref"
    "attribute.environment" = "assertion.environment"
  }

  # Only OUR repository can exchange tokens. Without this condition, any GitHub
  # repo could try to impersonate the service account.
  attribute_condition = "assertion.repository == '${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "github_impersonation" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

output "workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}

output "terraform_service_account" {
  value = google_service_account.terraform.email
}

output "folder_ids" {
  value = { for k, f in google_folder.env : k => f.name }
}
