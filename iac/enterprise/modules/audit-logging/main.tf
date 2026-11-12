/**
 * Module: audit-logging
 *
 * Org-wide audit trail that nobody, including org admins, can shorten or delete:
 *   1. An aggregated org sink sends all audit logs to a CMEK-encrypted,
 *      retention-LOCKED Cloud Logging bucket (5 years, queryable).
 *   2. A second sink sends the same logs to a Cloud Storage bucket with a locked
 *      retention policy (10 years, cheap Archive class) for AML record-keeping.
 *
 * ⚠️ Locking is irreversible. Keep lock_* = false in sandboxes.
 */

# --- 1. Queryable log bucket (Cloud Logging) ---------------------------------

data "google_logging_project_cmek_settings" "this" {
  project = var.logging_project_id
}

resource "google_kms_crypto_key_iam_member" "logging_sa" {
  crypto_key_id = var.kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_logging_project_cmek_settings.this.service_account_id}"
}

resource "google_logging_project_bucket_config" "audit" {
  project        = var.logging_project_id
  location       = var.location
  bucket_id      = "org-audit-logs"
  retention_days = var.log_bucket_retention_days
  locked         = var.lock_log_bucket

  # Log Analytics: query audit evidence with SQL (see docs/10-evidence-register.md).
  # Works with CMEK buckets; cross-bucket queries need the same key or a common
  # ancestor default key, otherwise temporary join data uses Google-managed keys.
  enable_analytics = true

  cmek_settings {
    kms_key_name = var.kms_key_id
  }

  depends_on = [google_kms_crypto_key_iam_member.logging_sa]
}

resource "google_logging_organization_sink" "to_log_bucket" {
  name             = "org-audit-to-locked-log-bucket"
  org_id           = var.org_id
  destination      = "logging.googleapis.com/${google_logging_project_bucket_config.audit.id}"
  include_children = true
  filter           = var.filter
}

resource "google_project_iam_member" "log_bucket_writer" {
  project = var.logging_project_id
  role    = "roles/logging.bucketWriter"
  member  = google_logging_organization_sink.to_log_bucket.writer_identity
}

# --- 2. Long-term WORM archive (Cloud Storage) -------------------------------

data "google_storage_project_service_account" "gcs" {
  project = var.logging_project_id
}

resource "google_kms_crypto_key_iam_member" "gcs_sa" {
  crypto_key_id = var.kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs.email_address}"
}

resource "google_storage_bucket" "archive" {
  project                     = var.logging_project_id
  name                        = "${var.logging_project_id}-audit-archive"
  location                    = var.location
  storage_class               = "ARCHIVE"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  retention_policy {
    retention_period = tostring(var.archive_retention_days * 86400) # string since provider v7
    is_locked        = var.lock_archive_bucket
  }

  encryption {
    default_kms_key_name = var.kms_key_id
  }

  lifecycle_rule {
    condition {
      age = var.archive_retention_days + 1
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_kms_crypto_key_iam_member.gcs_sa]
}

resource "google_logging_organization_sink" "to_archive" {
  name             = "org-audit-to-worm-archive"
  org_id           = var.org_id
  destination      = "storage.googleapis.com/${google_storage_bucket.archive.name}"
  include_children = true
  filter           = var.filter
}

resource "google_storage_bucket_iam_member" "archive_writer" {
  bucket = google_storage_bucket.archive.name
  role   = "roles/storage.objectCreator"
  member = google_logging_organization_sink.to_archive.writer_identity
}

# --- 3. Turn ON data-access logs (off by default for most services) ----------

resource "google_organization_iam_audit_config" "all_services" {
  org_id  = var.org_id
  service = "allServices"

  audit_log_config {
    log_type = "ADMIN_READ"
  }
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}
