/**
 * Module: platform (Quillpay)
 *
 * One "jurisdiction cell" of the Sentinel platform, fully managed (Case 1),
 * sized for a startup:
 *
 *   Cloud Run (scoring) → Cloud SQL Postgres (ledger) + Pub/Sub (events)
 *   → BigQuery (analytics + privacy registers) + GCS (WORM archive, breach records)
 *
 * Everything is CMEK-encrypted with keys in a sibling KMS project. The same module
 * deploys the EU cell (GDPR) and the Canadian cell (PIPEDA); see envs/.
 *
 * Startup trade-off: Cloud SQL instead of Spanner. It's roughly 10x cheaper at low
 * volume, and the migration path to Spanner (PostgreSQL dialect) is in docs/iac/06.
 */

locals {
  cell   = "${var.prefix}-${var.environment}-${var.jurisdiction}"
  labels = merge(var.labels, { jurisdiction = var.jurisdiction, environment = var.environment, managed_by = "terraform" })
}

# --- Projects ------------------------------------------------------------------

resource "google_project" "app" {
  name                = "${local.cell}-app"
  project_id          = "${local.cell}-app"
  folder_id           = var.folder_id
  billing_account     = var.billing_account
  auto_create_network = false
  deletion_policy     = var.environment == "prod" ? "PREVENT" : "DELETE"
  labels              = merge(local.labels, { data_classification = "confidential" })
}

resource "google_project" "kms" {
  name                = "${local.cell}-kms"
  project_id          = "${local.cell}-kms"
  folder_id           = var.folder_id
  billing_account     = var.billing_account
  auto_create_network = false
  deletion_policy     = "PREVENT"
  labels              = merge(local.labels, { data_classification = "restricted" })
}

resource "google_project_service" "app" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "cloudkms.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
  ])
  project            = google_project.app.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_project_service" "kms" {
  project            = google_project.kms.project_id
  service            = "cloudkms.googleapis.com"
  disable_on_destroy = false
}

# --- Service agents ------------------------------------------------------------------

resource "google_project_service_identity" "agents" {
  provider = google-beta
  for_each = toset(["artifactregistry.googleapis.com", "sqladmin.googleapis.com", "secretmanager.googleapis.com", "pubsub.googleapis.com"])

  project    = google_project.app.project_id
  service    = each.value
  depends_on = [google_project_service.app]
}

data "google_storage_project_service_account" "gcs" {
  project    = google_project.app.project_id
  depends_on = [google_project_service.app]
}

data "google_bigquery_default_service_account" "bq" {
  project    = google_project.app.project_id
  depends_on = [google_project_service.app]
}

locals {
  # Static keys so for_each is known at plan time (member values aren't).
  agent_members = {
    artifactregistry = google_project_service_identity.agents["artifactregistry.googleapis.com"].member
    cloudsql         = google_project_service_identity.agents["sqladmin.googleapis.com"].member
    secretmanager    = google_project_service_identity.agents["secretmanager.googleapis.com"].member
    pubsub           = google_project_service_identity.agents["pubsub.googleapis.com"].member
    storage          = "serviceAccount:${data.google_storage_project_service_account.gcs.email_address}"
    bigquery         = "serviceAccount:${data.google_bigquery_default_service_account.bq.email}"
    cloudrun         = "serviceAccount:service-${google_project.app.number}@serverless-robot-prod.iam.gserviceaccount.com"
  }
}

# --- CMEK ------------------------------------------------------------------

resource "google_kms_key_ring" "cell" {
  project    = google_project.kms.project_id
  name       = "kr-${local.cell}"
  location   = var.region
  depends_on = [google_project_service.kms]
}

resource "google_kms_crypto_key" "data" {
  name                       = "key-data"
  key_ring                   = google_kms_key_ring.cell.id
  rotation_period            = "7776000s"
  destroy_scheduled_duration = "86400s"
  labels                     = local.labels

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = var.environment == "prod" ? "HSM" : "SOFTWARE"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key_iam_member" "agents" {
  for_each      = local.agent_members
  crypto_key_id = google_kms_crypto_key.data.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = each.value
}

# --- Network ---------------------------------------------------------------

resource "google_compute_network" "vpc" {
  project                 = google_project.app.project_id
  name                    = "vpc-${local.cell}"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.app]
}

resource "google_compute_subnetwork" "run" {
  project                  = google_project.app.project_id
  name                     = "snet-run"
  network                  = google_compute_network.vpc.id
  region                   = var.region
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.2
  }
}

resource "google_compute_global_address" "psa" {
  project       = google_project.app.project_id
  name          = "psa-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "psa" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa.name]
}

# --- Identities ------------------------------------------------------------

resource "google_service_account" "scoring" {
  project      = google_project.app.project_id
  account_id   = "sa-scoring"
  display_name = "Cloud Run scoring service"
}

resource "google_service_account" "dsr" {
  project      = google_project.app.project_id
  account_id   = "sa-dsr-executor"
  display_name = "Privacy request executor (access, erasure, PIPEDA disclosure accounts)"
}

# --- Artifact Registry + Secret Manager ----------------------------------------

resource "google_artifact_registry_repository" "images" {
  project       = google_project.app.project_id
  location      = var.region
  repository_id = "images"
  format        = "DOCKER"
  kms_key_name  = google_kms_crypto_key.data.id
  labels        = local.labels
  depends_on    = [google_kms_crypto_key_iam_member.agents]
}

resource "google_secret_manager_secret" "db_app" {
  project   = google_project.app.project_id
  secret_id = "ledger-app-config"
  labels    = local.labels

  replication {
    user_managed {
      replicas {
        location = var.region
        customer_managed_encryption {
          kms_key_name = google_kms_crypto_key.data.id
        }
      }
    }
  }

  depends_on = [google_kms_crypto_key_iam_member.agents]
}

# --- Ledger: Cloud SQL for PostgreSQL --------------------------------------

resource "google_sql_database_instance" "ledger" {
  project             = google_project.app.project_id
  name                = "sql-${local.cell}-ledger"
  region              = var.region
  database_version    = "POSTGRES_16"
  encryption_key_name = google_kms_crypto_key.data.id
  deletion_protection = var.environment == "prod"

  settings {
    tier              = var.sql_tier
    edition           = "ENTERPRISE"
    availability_type = var.environment == "prod" ? "REGIONAL" : "ZONAL"
    user_labels       = local.labels

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      location                       = var.backup_location
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = 30
      }
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    insights_config {
      query_insights_enabled = true
    }

    maintenance_window {
      day  = 7
      hour = 3
    }
  }

  depends_on = [google_service_networking_connection.psa, google_kms_crypto_key_iam_member.agents]
}

# --- Events: Pub/Sub ---------------------------------------------------------

resource "google_pubsub_topic" "events" {
  for_each = toset(["payments-raw", "decisions", "privacy-commands"])

  project                    = google_project.app.project_id
  name                       = each.value
  kms_key_name               = google_kms_crypto_key.data.id
  message_retention_duration = "604800s"
  labels                     = local.labels

  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }

  depends_on = [google_kms_crypto_key_iam_member.agents]
}

# --- Scoring: Cloud Run --------------------------------------------------------

resource "google_cloud_run_v2_service" "scoring" {
  project  = google_project.app.project_id
  name     = "scoring"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  labels   = local.labels

  template {
    service_account = google_service_account.scoring.email
    encryption_key  = google_kms_crypto_key.data.id

    scaling {
      min_instance_count = var.environment == "prod" ? 2 : 0
      max_instance_count = var.max_instances
    }

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"
      network_interfaces {
        network    = google_compute_network.vpc.id
        subnetwork = google_compute_subnetwork.run.id
      }
    }

    containers {
      image = var.scoring_image

      env {
        name  = "JURISDICTION"
        value = var.jurisdiction
      }

      resources {
        limits = {
          cpu    = "2"
          memory = "1Gi"
        }
        cpu_idle          = false
        startup_cpu_boost = true
      }
    }
  }

  depends_on = [google_kms_crypto_key_iam_member.agents]
}

# --- Analytics + privacy registers: BigQuery --------------------------------------

resource "google_bigquery_dataset" "analytics" {
  project       = google_project.app.project_id
  dataset_id    = "analytics"
  location      = var.bq_location
  labels        = local.labels
  friendly_name = "Pseudonymised analytics"

  default_partition_expiration_ms = 400 * 24 * 3600 * 1000 # ~13 months

  default_encryption_configuration {
    kms_key_name = google_kms_crypto_key.data.id
  }

  depends_on = [google_kms_crypto_key_iam_member.agents]
}

resource "google_bigquery_dataset" "privacy" {
  project       = google_project.app.project_id
  dataset_id    = "privacy"
  location      = var.bq_location
  labels        = local.labels
  friendly_name = "Privacy registers: consent ledger, disclosure log, breach register, DSR log"

  default_encryption_configuration {
    kms_key_name = google_kms_crypto_key.data.id
  }

  depends_on = [google_kms_crypto_key_iam_member.agents]
}

resource "google_bigquery_table" "privacy" {
  for_each = local.privacy_tables

  project             = google_project.app.project_id
  dataset_id          = google_bigquery_dataset.privacy.dataset_id
  table_id            = each.key
  description         = each.value.description
  deletion_protection = true
  schema              = jsonencode(each.value.schema)

  time_partitioning {
    type  = "DAY"
    field = "event_time"
  }
}

# --- Storage: WORM archive + breach-record vault --------------------------------

resource "google_storage_bucket" "archive" {
  project                     = google_project.app.project_id
  name                        = "${local.cell}-archive"
  location                    = var.region
  storage_class               = "ARCHIVE"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  enable_object_retention     = true # per-object legal holds and retention (AML)
  labels                      = local.labels

  encryption {
    default_kms_key_name = google_kms_crypto_key.data.id
  }

  depends_on = [google_kms_crypto_key_iam_member.agents]
}

# PIPEDA s.10.3 + Breach of Security Safeguards Regulations: keep a record of EVERY
# breach (reportable or not) for at least 24 months after the determination.
# GDPR Art. 33(5) also requires documenting all breaches, without a fixed period.
# One bucket serves both, with a 36-month locked retention.
resource "google_storage_bucket" "breach_records" {
  project                     = google_project.app.project_id
  name                        = "${local.cell}-breach-records"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  labels                      = merge(local.labels, { purpose = "breach-register" })

  retention_policy {
    retention_period = tostring(var.breach_record_retention_days * 86400) # string since provider v7
    is_locked        = var.lock_retention
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.data.id
  }

  depends_on = [google_kms_crypto_key_iam_member.agents]
}

# --- Least-privilege IAM ---------------------------------------------------------

resource "google_project_iam_member" "scoring" {
  for_each = toset(["roles/cloudsql.client", "roles/cloudsql.instanceUser", "roles/pubsub.publisher", "roles/logging.logWriter"])
  project  = google_project.app.project_id
  role     = each.value
  member   = google_service_account.scoring.member
}

resource "google_bigquery_dataset_iam_member" "dsr_privacy" {
  project    = google_project.app.project_id
  dataset_id = google_bigquery_dataset.privacy.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_service_account.dsr.member
}

# --- Budget ------------------------------------------------------------------

resource "google_billing_budget" "cell" {
  billing_account = var.billing_account
  display_name    = "${local.cell}-budget"

  budget_filter {
    projects = ["projects/${google_project.app.number}"]
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency
      units         = tostring(var.monthly_budget)
    }
  }

  threshold_rules {
    threshold_percent = 0.8
  }
  threshold_rules {
    threshold_percent = 1.0
  }
}
