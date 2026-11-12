output "network_id" {
  value = google_compute_network.this.id
}

output "network_self_link" {
  value = google_compute_network.this.self_link
}

output "subnets" {
  description = "Map of subnet name => { id, self_link, region }."
  value = {
    for k, s in google_compute_subnetwork.this : k => {
      id        = s.id
      self_link = s.self_link
      region    = s.region
    }
  }
}
