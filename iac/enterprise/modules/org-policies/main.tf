/**
 * Module: org-policies
 *
 * Preventive guardrails ("Privacy by default", GDPR Art. 25) applied to an
 * organization or folder. Every constraint here maps to a row in
 * docs/03-compliance-controls.md section 5.
 */

locals {
  # Boolean constraints that are simply switched on.
  boolean_constraints = toset([
    "iam.disableServiceAccountKeyCreation",            # no long-lived SA keys
    "iam.automaticIamGrantsForDefaultServiceAccounts", # default SAs get no Editor
    "storage.uniformBucketLevelAccess",                # no object ACLs
    "storage.publicAccessPrevention",                  # no public buckets
    "sql.restrictPublicIp",                            # no public Cloud SQL
    "compute.requireOsLogin",                          # SSH tied to IAM identity
    "compute.skipDefaultNetworkCreation",              # no default VPC
    "compute.disableSerialPortAccess",
    "compute.requireShieldedVm",
  ])
}

resource "google_org_policy_policy" "boolean" {
  for_each = local.boolean_constraints

  name   = "${var.parent}/policies/${each.value}"
  parent = var.parent

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# GDPR Art. 44: data residency. Only EU locations may host resources.
resource "google_org_policy_policy" "resource_locations" {
  name   = "${var.parent}/policies/gcp.resourceLocations"
  parent = var.parent

  spec {
    rules {
      values {
        allowed_values = var.allowed_locations
      }
    }
  }
}

# Only identities from our own Cloud Identity / Workspace customer(s).
resource "google_org_policy_policy" "allowed_member_domains" {
  name   = "${var.parent}/policies/iam.allowedPolicyMemberDomains"
  parent = var.parent

  spec {
    rules {
      values {
        allowed_values = var.allowed_customer_ids
      }
    }
  }
}

# No external IPs on VMs (exceptions are granted per folder, see landing-zone/tech-debt.tf).
resource "google_org_policy_policy" "vm_external_ip" {
  name   = "${var.parent}/policies/compute.vmExternalIpAccess"
  parent = var.parent

  spec {
    rules {
      deny_all = "TRUE"
    }
  }
}

# Services listed here MUST be created with a customer-managed key (CMEK).
# Note: this is a deny-list. "Denied" means "denied without CMEK".
resource "google_org_policy_policy" "restrict_non_cmek" {
  count = length(var.cmek_required_services) > 0 ? 1 : 0

  name   = "${var.parent}/policies/gcp.restrictNonCmekServices"
  parent = var.parent

  spec {
    rules {
      values {
        denied_values = var.cmek_required_services
      }
    }
  }
}

# CMEK keys may only come from the central KMS project(s): separation of duties.
resource "google_org_policy_policy" "restrict_cmek_projects" {
  count = length(var.kms_project_ids) > 0 ? 1 : 0

  name   = "${var.parent}/policies/gcp.restrictCmekCryptoKeyProjects"
  parent = var.parent

  spec {
    rules {
      values {
        allowed_values = [for p in var.kms_project_ids : "under:projects/${p}"]
      }
    }
  }
}

# Demand management hook: only services that passed a security assessment
# (and therefore appear in this allow-list) can be enabled.
resource "google_org_policy_policy" "restrict_service_usage" {
  count = length(var.allowed_services) > 0 ? 1 : 0

  name   = "${var.parent}/policies/gcp.restrictServiceUsage"
  parent = var.parent

  spec {
    rules {
      values {
        allowed_values = var.allowed_services
      }
    }
  }
}
