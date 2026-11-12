output "project_id" {
  value = google_project.this.project_id
}

output "project_number" {
  value = google_project.this.number
}

output "apis" {
  description = "Enabled services. Use in depends_on to avoid race conditions."
  value       = [for s in google_project_service.apis : s.service]
}
