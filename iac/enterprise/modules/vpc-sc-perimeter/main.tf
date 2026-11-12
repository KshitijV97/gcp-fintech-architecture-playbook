/**
 * Module: vpc-sc-perimeter
 *
 * A VPC Service Controls perimeter: the main data-exfiltration control.
 *
 * Rollout pattern (an enterprise change-management best practice):
 *   1. enforce = false -> perimeter is created in DRY-RUN mode (spec only).
 *      Violations are logged but not blocked.
 *   2. Review "vpcServiceControlsUniqueId" violations in the audit log bucket
 *      for at least one full business cycle (e.g. month-end close).
 *   3. Raise a Normal change, CAB approves, set enforce = true.
 */

locals {
  resources = [for n in var.project_numbers : "projects/${n}"]
}

resource "google_access_context_manager_service_perimeter" "this" {
  parent         = "accessPolicies/${var.access_policy_id}"
  name           = "accessPolicies/${var.access_policy_id}/servicePerimeters/${var.name}"
  title          = var.name
  perimeter_type = "PERIMETER_TYPE_REGULAR"

  use_explicit_dry_run_spec = !var.enforce

  # ENFORCED configuration
  dynamic "status" {
    for_each = var.enforce ? [1] : []
    content {
      resources           = local.resources
      restricted_services = var.restricted_services
      access_levels       = var.access_levels

      vpc_accessible_services {
        enable_restriction = true
        allowed_services   = ["RESTRICTED-SERVICES"]
      }

      dynamic "ingress_policies" {
        for_each = var.ingress_identities
        content {
          ingress_from {
            identities = [ingress_policies.value]
            sources {
              access_level = "*"
            }
          }
          ingress_to {
            resources = ["*"]
            operations {
              service_name = "*"
            }
          }
        }
      }
    }
  }

  # DRY-RUN configuration (logged, not enforced)
  dynamic "spec" {
    for_each = var.enforce ? [] : [1]
    content {
      resources           = local.resources
      restricted_services = var.restricted_services
      access_levels       = var.access_levels

      vpc_accessible_services {
        enable_restriction = true
        allowed_services   = ["RESTRICTED-SERVICES"]
      }

      dynamic "ingress_policies" {
        for_each = var.ingress_identities
        content {
          ingress_from {
            identities = [ingress_policies.value]
            sources {
              access_level = "*"
            }
          }
          ingress_to {
            resources = ["*"]
            operations {
              service_name = "*"
            }
          }
        }
      }
    }
  }
}
