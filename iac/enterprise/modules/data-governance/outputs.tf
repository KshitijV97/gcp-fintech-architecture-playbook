output "taxonomy_id" {
  value = google_data_catalog_taxonomy.privacy.id
}

output "policy_tags" {
  description = "Map of classification => policy tag name (use in BigQuery schema policyTags)."
  value       = { for k, t in google_data_catalog_policy_tag.leaf : k => t.name }
}

output "privacy_aspect_type" {
  value = google_dataplex_aspect_type.privacy_record.name
}
