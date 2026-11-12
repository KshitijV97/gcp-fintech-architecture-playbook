output "key_ring_id" {
  value = google_kms_key_ring.this.id
}

output "key_ids" {
  description = "Map of key name => full key resource ID."
  value       = { for k, v in google_kms_crypto_key.keys : k => v.id }
}
