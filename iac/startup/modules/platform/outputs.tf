output "app_project_id" {
  value = google_project.app.project_id
}

output "kms_key_id" {
  value = google_kms_crypto_key.data.id
}

output "scoring_service" {
  value = google_cloud_run_v2_service.scoring.uri
}

output "ledger_instance" {
  value = google_sql_database_instance.ledger.connection_name
}

output "privacy_dataset" {
  value = google_bigquery_dataset.privacy.dataset_id
}

output "breach_records_bucket" {
  value = google_storage_bucket.breach_records.name
}
