output "project_id" {
  value = module.project.project_id
}

output "gke_cluster" {
  value = google_container_cluster.this.name
}

output "ledger_cluster" {
  value = google_alloydb_cluster.ledger.name
}

output "kafka_cluster" {
  value = google_managed_kafka_cluster.events.name
}
