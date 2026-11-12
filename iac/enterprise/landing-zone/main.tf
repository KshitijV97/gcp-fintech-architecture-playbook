/**
 * Aldervane Bank: landing zone (stage 1)
 *
 * Builds the organisation skeleton that every workload lands in:
 *
 *   Organization
 *   ├── fldr-security      logging, KMS, SecOps projects
 *   ├── fldr-network       Shared VPC host projects
 *   ├── fldr-eu-prod       (Assured Workloads: EU Regions and Support) GDPR cell
 *   ├── fldr-eu-nonprod
 *   ├── fldr-ca-prod       (Assured Workloads: Canada Regions and Support) PIPEDA/OSFI cell (Case 5)
 *   ├── fldr-legacy        quarantine for technical debt, with documented exceptions
 *   └── fldr-sandbox       no production data, auto-expiring projects
 */

locals {
  org = "organizations/${var.org_id}"

  folders = {
    security   = "fldr-security"
    network    = "fldr-network"
    eu_prod    = "fldr-eu-prod"
    eu_nonprod = "fldr-eu-nonprod"
    ca_prod    = "fldr-ca-prod"
    legacy     = "fldr-legacy"
    sandbox    = "fldr-sandbox"
  }

  # Org level: union of every jurisdiction we operate in. Folders narrow it further.
  org_allowed_locations = [
    "in:eu-locations",
    "in:northamerica-northeast1-locations", # Montréal
    "in:northamerica-northeast2-locations", # Toronto
  ]
}

# --- Folders -----------------------------------------------------------------

resource "google_folder" "this" {
  for_each = local.folders

  display_name        = each.value
  parent              = local.org
  deletion_protection = true
}

# --- Org-wide guardrails -----------------------------------------------------

module "org_policies" {
  source = "../modules/org-policies"

  parent               = local.org
  allowed_locations    = local.org_allowed_locations
  allowed_customer_ids = ["is:${var.customer_id}"]
  kms_project_ids      = [module.kms_eu.project_id, module.kms_ca.project_id]
  allowed_services     = var.approved_services
}

# --- Jurisdiction cells: narrow resource locations per folder -----------------

resource "google_org_policy_policy" "eu_locations" {
  for_each = toset(["eu_prod", "eu_nonprod"])

  name   = "${google_folder.this[each.key].name}/policies/gcp.resourceLocations"
  parent = google_folder.this[each.key].name

  spec {
    rules {
      values {
        allowed_values = ["in:eu-locations"]
      }
    }
  }
}

resource "google_org_policy_policy" "ca_locations" {
  name   = "${google_folder.this["ca_prod"].name}/policies/gcp.resourceLocations"
  parent = google_folder.this["ca_prod"].name

  spec {
    rules {
      values {
        allowed_values = [
          "in:northamerica-northeast1-locations",
          "in:northamerica-northeast2-locations",
        ]
      }
    }
  }
}

# --- Assured Workloads (optional; creates its own managed sub-folders) --------
# Regimes EU_REGIONS_AND_SUPPORT and CA_REGIONS_AND_SUPPORT are valid provider
# enums (v8.11). display_name: 4-30 chars. Regional availability of each regime
# is org-specific: confirm in the console before enabling in a real org.

resource "google_assured_workloads_workload" "eu" {
  count = var.enable_assured_workloads ? 1 : 0

  organization                 = var.org_id
  location                     = var.eu_primary_region
  display_name                 = "aw-eu-sentinel-prod"
  compliance_regime            = "EU_REGIONS_AND_SUPPORT"
  billing_account              = "billingAccounts/${var.billing_account}"
  provisioned_resources_parent = google_folder.this["eu_prod"].name
}

resource "google_assured_workloads_workload" "ca" {
  count = var.enable_assured_workloads ? 1 : 0

  organization                 = var.org_id
  location                     = var.ca_primary_region
  display_name                 = "aw-ca-sentinel-prod"
  compliance_regime            = "CA_REGIONS_AND_SUPPORT"
  billing_account              = "billingAccounts/${var.billing_account}"
  provisioned_resources_parent = google_folder.this["ca_prod"].name
}

# --- Security projects -------------------------------------------------------

module "logging_project" {
  source = "../modules/project-factory"

  prefix              = var.prefix
  environment         = "sec"
  name                = "audit-logs"
  folder_id           = google_folder.this["security"].name
  billing_account     = var.billing_account
  cost_center         = "cc-0100-security"
  data_classification = "confidential"
  owner               = "security-engineering"
  demand_id           = "dmd-0001"
  security_contacts   = var.security_contacts
  apis                = ["logging.googleapis.com", "storage.googleapis.com", "cloudkms.googleapis.com"]
  monthly_budget_eur  = 3000
}

module "kms_eu" {
  source = "../modules/project-factory"

  prefix              = var.prefix
  environment         = "sec"
  name                = "kms-eu"
  folder_id           = google_folder.this["security"].name
  billing_account     = var.billing_account
  cost_center         = "cc-0100-security"
  data_classification = "restricted"
  owner               = "crypto-office"
  demand_id           = "dmd-0001"
  security_contacts   = var.security_contacts
  apis                = ["cloudkms.googleapis.com"]
  monthly_budget_eur  = 1000
}

module "kms_ca" {
  source = "../modules/project-factory"

  prefix              = var.prefix
  environment         = "sec"
  name                = "kms-ca"
  folder_id           = google_folder.this["security"].name
  billing_account     = var.billing_account
  cost_center         = "cc-0100-security"
  data_classification = "restricted"
  owner               = "crypto-office"
  demand_id           = "dmd-0057"
  security_contacts   = var.security_contacts
  apis                = ["cloudkms.googleapis.com"]
  monthly_budget_eur  = 500
}

module "logging_cmek" {
  source = "../modules/cmek"

  project_id    = module.kms_eu.project_id
  location      = var.eu_primary_region
  key_ring_name = "kr-audit-logs"
  keys = {
    "key-audit-logs" = { data_domain = "audit" }
  }
}

module "audit_logging" {
  source = "../modules/audit-logging"

  org_id              = var.org_id
  logging_project_id  = module.logging_project.project_id
  location            = var.eu_primary_region
  kms_key_id          = module.logging_cmek.key_ids["key-audit-logs"]
  lock_log_bucket     = var.lock_audit_buckets
  lock_archive_bucket = var.lock_audit_buckets
}

# --- Network hub -------------------------------------------------------------

module "net_host_eu" {
  source = "../modules/project-factory"

  prefix              = var.prefix
  environment         = "net"
  name                = "host-eu-prd"
  folder_id           = google_folder.this["network"].name
  billing_account     = var.billing_account
  cost_center         = "cc-0200-network"
  data_classification = "internal"
  owner               = "network-engineering"
  demand_id           = "dmd-0001"
  apis                = ["compute.googleapis.com", "dns.googleapis.com", "servicenetworking.googleapis.com"]
}

module "shared_vpc_eu" {
  source = "../modules/shared-vpc"

  host_project_id = module.net_host_eu.project_id
  network_name    = "vpc-eu-prd"
  subnets = {
    "snet-sentinel-euw3" = {
      region = var.eu_primary_region
      cidr   = "10.10.0.0/20"
      secondary_ranges = {
        "gke-pods"     = "10.20.0.0/16"
        "gke-services" = "10.30.0.0/20"
      }
    }
    "snet-sentinel-euw4" = {
      region = "europe-west4"
      cidr   = "10.11.0.0/20"
      secondary_ranges = {
        "gke-pods"     = "10.21.0.0/16"
        "gke-services" = "10.31.0.0/20"
      }
    }
  }
}
