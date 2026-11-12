/**
 * Workload: Project Sentinel, Aldervane edition (Case 2: semi-managed)
 *
 * GKE Standard (private, CMEK, Workload Identity, Binary Authorization)
 * + AlloyDB decision ledger (HA, CMEK, continuous backup)
 * + Managed Service for Apache Kafka (CMEK)
 * + VPC Service Controls perimeter (dry-run first)
 *
 * The maintenance window is aligned to the CAB-approved change window
 * (Saturday 01:00–05:00 UTC). See change-management/README.md.
 */

locals {
  labels = {
    workload            = "sentinel"
    environment         = var.environment
    data_classification = "confidential"
    jurisdiction        = var.jurisdiction
  }
}

# --- Project -----------------------------------------------------------------

module "project" {
  source = "../../modules/project-factory"

  prefix                     = var.prefix
  environment                = var.environment
  name                       = "sentinel"
  folder_id                  = var.folder_id
  billing_account            = var.billing_account
  cost_center                = "cc-4410-fraud"
  data_classification        = "confidential"
  owner                      = "fraud-platform"
  demand_id                  = var.demand_id
  shared_vpc_host_project_id = var.network.host_project_id
  security_contacts          = var.security_contacts
  monthly_budget_eur         = var.monthly_budget_eur
  extra_labels               = { jurisdiction = var.jurisdiction }

  apis = [
    "alloydb.googleapis.com",
    "artifactregistry.googleapis.com",
    "binaryauthorization.googleapis.com",
    "cloudkms.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "logging.googleapis.com",
    "managedkafka.googleapis.com",
    "monitoring.googleapis.com",
    "servicenetworking.googleapis.com",
  ]
}

# --- Service agents that need key access ---------------------------------------

resource "google_project_service_identity" "alloydb" {
  provider = google-beta
  project  = module.project.project_id
  service  = "alloydb.googleapis.com"
}

resource "google_project_service_identity" "kafka" {
  provider = google-beta
  project  = module.project.project_id
  service  = "managedkafka.googleapis.com"
}

locals {
  n = module.project.project_number

  agents = {
    gke     = "serviceAccount:service-${local.n}@container-engine-robot.iam.gserviceaccount.com"
    compute = "serviceAccount:service-${local.n}@compute-system.iam.gserviceaccount.com"
    alloydb = google_project_service_identity.alloydb.member
    kafka   = google_project_service_identity.kafka.member
  }
}

# --- CMEK keys (in the central KMS project) -----------------------------------

module "cmek" {
  source = "../../modules/cmek"

  project_id    = var.kms_project_id
  location      = var.region
  key_ring_name = "kr-${var.environment}-sentinel"
  labels        = local.labels

  keys = {
    "key-gke"    = { data_domain = "platform" }
    "key-ledger" = { data_domain = "decision-ledger", destroy_scheduled_duration = "2592000s" }
    "key-events" = { data_domain = "payment-events" }
  }

  encrypters = {
    "key-gke"    = [local.agents.gke, local.agents.compute]
    "key-ledger" = [local.agents.alloydb]
    "key-events" = [local.agents.kafka]
  }
}

# --- GKE Standard ------------------------------------------------------------

resource "google_service_account" "gke_nodes" {
  project      = module.project.project_id
  account_id   = "sa-gke-nodes"
  display_name = "GKE node identity (minimal permissions)"
}

resource "google_project_iam_member" "gke_nodes" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/artifactregistry.reader",
  ])

  project = module.project.project_id
  role    = each.value
  member  = google_service_account.gke_nodes.member
}

resource "google_container_cluster" "this" {
  project  = module.project.project_id
  name     = "gke-${var.environment}-sentinel"
  location = var.region

  network    = var.network.network_id
  subnetwork = var.network.subnet_self_link

  # No default node pool: on GKE 1.36.4+ omitting initial_node_count/node_config
  # replaces the deprecated remove_default_node_pool pattern (provider v8).
  deletion_protection   = true
  datapath_provider     = "ADVANCED_DATAPATH"
  enable_shielded_nodes = true

  release_channel {
    channel = "STABLE"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = var.master_cidr
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_cidrs
      content {
        cidr_block   = cidr_blocks.value
        display_name = "authorized-${cidr_blocks.key}"
      }
    }
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  workload_identity_config {
    workload_pool = "${module.project.project_id}.svc.id.goog"
  }

  # Application-layer encryption of Kubernetes Secrets in etcd.
  database_encryption {
    state    = "ENCRYPTED"
    key_name = module.cmek.key_ids["key-gke"]
  }

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }

  # Aligned to the CAB standard change window.
  maintenance_policy {
    recurring_window {
      start_time = "2026-01-03T01:00:00Z"
      end_time   = "2026-01-03T05:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SA"
    }
  }

  resource_labels = local.labels
}

resource "google_container_node_pool" "scoring" {
  project  = module.project.project_id
  name     = "np-scoring"
  cluster  = google_container_cluster.this.id
  location = var.region

  autoscaling {
    min_node_count = var.scoring_nodes.min
    max_node_count = var.scoring_nodes.max
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type      = var.scoring_nodes.machine_type
    service_account   = google_service_account.gke_nodes.email
    oauth_scopes      = ["https://www.googleapis.com/auth/cloud-platform"]
    boot_disk_kms_key = module.cmek.key_ids["key-gke"]
    labels            = local.labels

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

# --- AlloyDB decision ledger ---------------------------------------------------

resource "google_alloydb_cluster" "ledger" {
  project    = module.project.project_id
  cluster_id = "adb-${var.environment}-ledger"
  location   = var.region

  # Default true since provider v7; set explicitly so intent is visible in review.
  deletion_protection = true

  network_config {
    network = var.network.network_id
  }

  encryption_config {
    kms_key_name = module.cmek.key_ids["key-ledger"]
  }

  continuous_backup_config {
    enabled              = true
    recovery_window_days = 14
    encryption_config {
      kms_key_name = module.cmek.key_ids["key-ledger"]
    }
  }

  automated_backup_policy {
    location      = var.region
    backup_window = "3600s"
    enabled       = true

    weekly_schedule {
      days_of_week = ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"]
      start_times {
        hours = 2
      }
    }

    quantity_based_retention {
      count = 35
    }

    encryption_config {
      kms_key_name = module.cmek.key_ids["key-ledger"]
    }
  }

  labels = local.labels

  depends_on = [module.cmek]
}

resource "google_alloydb_instance" "ledger_primary" {
  cluster           = google_alloydb_cluster.ledger.name
  instance_id       = "primary"
  instance_type     = "PRIMARY"
  availability_type = "REGIONAL" # HA standby in a second zone

  machine_config {
    cpu_count = var.ledger_vcpus
  }

  database_flags = {
    "alloydb.iam_authentication"  = "on"
    "password.enforce_complexity" = "on"
  }
}

# --- Managed Service for Apache Kafka -----------------------------------------

resource "google_managed_kafka_cluster" "events" {
  project    = module.project.project_id
  cluster_id = "kafka-${var.environment}-sentinel"
  location   = var.region

  capacity_config {
    vcpu_count   = var.kafka_capacity.vcpu
    memory_bytes = var.kafka_capacity.memory_gib * 1073741824
  }

  gcp_config {
    access_config {
      network_configs {
        subnet = var.network.subnet_id
      }
    }
    kms_key = module.cmek.key_ids["key-events"]
  }

  rebalance_config {
    mode = "AUTO_REBALANCE_ON_SCALE_UP"
  }

  labels = local.labels
}

resource "google_managed_kafka_topic" "this" {
  for_each = var.kafka_topics

  project            = module.project.project_id
  location           = var.region
  cluster            = google_managed_kafka_cluster.events.cluster_id
  topic_id           = each.key
  partition_count    = each.value.partitions
  replication_factor = 3

  configs = {
    "retention.ms"   = tostring(each.value.retention_hours * 3600000)
    "cleanup.policy" = each.value.cleanup_policy
  }
}

# --- VPC Service Controls ------------------------------------------------------

module "perimeter" {
  source = "../../modules/vpc-sc-perimeter"

  access_policy_id   = var.access_policy_id
  name               = "sentinel_${var.environment}"
  project_numbers    = [module.project.project_number]
  ingress_identities = var.perimeter_ingress_identities
  enforce            = var.enforce_perimeter
}
