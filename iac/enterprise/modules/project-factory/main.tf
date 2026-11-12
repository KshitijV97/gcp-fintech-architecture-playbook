/**
 * Module: project-factory
 *
 * The ONLY approved way to create a project at Aldervane. It guarantees:
 *   - mandatory governance labels (cost centre, data classification, demand ID, owner)
 *   - no default network
 *   - deletion protection
 *   - essential contacts for security/legal notifications (GDPR Art. 33 readiness)
 *   - a budget with alerts (FinOps)
 *   - optional Shared VPC attachment
 */

locals {
  project_id = "${var.prefix}-${var.environment}-${var.name}"

  mandatory_labels = {
    environment         = var.environment
    cost_center         = var.cost_center
    data_classification = var.data_classification
    owner               = var.owner
    demand_id           = var.demand_id
    managed_by          = "terraform"
  }
}

resource "google_project" "this" {
  name                = local.project_id
  project_id          = local.project_id
  folder_id           = var.folder_id
  billing_account     = var.billing_account
  auto_create_network = false
  deletion_policy     = "PREVENT"

  labels = merge(var.extra_labels, local.mandatory_labels)
}

resource "google_project_service" "apis" {
  for_each = toset(var.apis)

  project            = google_project.this.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_shared_vpc_service_project" "this" {
  count = var.shared_vpc_host_project_id == null ? 0 : 1

  host_project    = var.shared_vpc_host_project_id
  service_project = google_project.this.project_id

  depends_on = [google_project_service.apis]
}

resource "google_essential_contacts_contact" "security" {
  for_each = toset(var.security_contacts)

  parent                              = "projects/${google_project.this.project_id}"
  email                               = each.value
  language_tag                        = "en"
  notification_category_subscriptions = ["SECURITY", "TECHNICAL", "LEGAL", "SUSPENSION"]

  depends_on = [google_project_service.apis]
}

resource "google_billing_budget" "this" {
  count = var.monthly_budget_eur > 0 ? 1 : 0

  billing_account = var.billing_account
  display_name    = "${local.project_id}-budget"

  budget_filter {
    projects = ["projects/${google_project.this.number}"]
  }

  amount {
    specified_amount {
      currency_code = "EUR"
      units         = tostring(var.monthly_budget_eur)
    }
  }

  dynamic "threshold_rules" {
    for_each = [0.5, 0.8, 1.0, 1.2]
    content {
      threshold_percent = threshold_rules.value
    }
  }
}
