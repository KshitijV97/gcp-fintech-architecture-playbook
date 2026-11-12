/**
 * Module: shared-vpc
 *
 * A Shared VPC host network with:
 *   - no default internet route (banks don't browse the internet from prod)
 *   - Private Google Access through the *restricted* VIP only (VPC-SC compatible)
 *   - private DNS that sends *.googleapis.com to restricted.googleapis.com
 *   - VPC flow logs on every subnet (DORA / forensic evidence)
 */

resource "google_compute_shared_vpc_host_project" "this" {
  project = var.host_project_id
}

resource "google_compute_network" "this" {
  project                         = var.host_project_id
  name                            = var.network_name
  auto_create_subnetworks         = false
  routing_mode                    = "GLOBAL"
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "this" {
  for_each = var.subnets

  project                  = var.host_project_id
  name                     = each.key
  network                  = google_compute_network.this.id
  region                   = each.value.region
  ip_cidr_range            = each.value.cidr
  private_ip_google_access = true

  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ranges
    content {
      range_name    = secondary_ip_range.key
      ip_cidr_range = secondary_ip_range.value
    }
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Route ONLY the restricted Google APIs VIP to the default gateway.
resource "google_compute_route" "restricted_vip" {
  project          = var.host_project_id
  name             = "${var.network_name}-restricted-googleapis"
  network          = google_compute_network.this.id
  dest_range       = "199.36.153.4/30"
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
}

resource "google_dns_managed_zone" "googleapis" {
  project    = var.host_project_id
  name       = "${var.network_name}-googleapis"
  dns_name   = "googleapis.com."
  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.this.id
    }
  }
}

resource "google_dns_record_set" "restricted_a" {
  project      = var.host_project_id
  managed_zone = google_dns_managed_zone.googleapis.name
  name         = "restricted.googleapis.com."
  type         = "A"
  ttl          = 300
  rrdatas      = ["199.36.153.4", "199.36.153.5", "199.36.153.6", "199.36.153.7"]
}

resource "google_dns_record_set" "wildcard_cname" {
  project      = var.host_project_id
  managed_zone = google_dns_managed_zone.googleapis.name
  name         = "*.googleapis.com."
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["restricted.googleapis.com."]
}

# Private Services Access range for AlloyDB / Cloud SQL / Memorystore.
resource "google_compute_global_address" "psa" {
  project       = var.host_project_id
  name          = "${var.network_name}-psa"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = split("/", var.psa_cidr)[0]
  prefix_length = tonumber(split("/", var.psa_cidr)[1])
  network       = google_compute_network.this.id
}

resource "google_service_networking_connection" "psa" {
  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa.name]
}
