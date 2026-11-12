output "log_bucket_id" {
  value = google_logging_project_bucket_config.audit.id
}

output "archive_bucket" {
  value = google_storage_bucket.archive.name
}
