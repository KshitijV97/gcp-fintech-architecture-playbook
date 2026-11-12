/**
 * Technical debt, made visible in code.
 *
 * Rules at Aldervane:
 *   1. Every exception to a guardrail lives in THIS file, never inline elsewhere.
 *   2. Every block carries a "TECH-DEBT TD-xxx" marker that matches a row in
 *      ../TECH_DEBT.md (owner, risk, compensating control, expiry date).
 *   3. The pipeline runs `scripts/check_tech_debt.sh`, which fails the build if a
 *      marker has no register entry or if the entry's expiry date has passed
 *      without a CAB-approved extension.
 */

# TECH-DEBT TD-007: The legacy SFTP gateway used by 3 correspondent banks needs a
# public IP until they move to Partner Interconnect (target 2027-Q2).
# Compensating controls: Cloud Armor allow-list, IDS, quarterly pen test.
resource "google_org_policy_policy" "legacy_sftp_external_ip" {
  name   = "${google_folder.this["legacy"].name}/policies/compute.vmExternalIpAccess"
  parent = google_folder.this["legacy"].name

  spec {
    rules {
      values {
        allowed_values = [
          "projects/${var.prefix}-lgc-sftp/zones/${var.eu_primary_region}-a/instances/sftp-gw-01",
        ]
      }
    }
  }
}

# TECH-DEBT TD-011: A third-party reconciliation tool (vendor "RecoSoft", v4)
# authenticates with a service-account key; vendor support for Workload Identity
# Federation is promised in v5 (2027-Q1).
# Compensating controls: key rotated every 30 days by a Cloud Scheduler job,
# key usage alerts, IAM Deny on every permission except storage.objects.get.
resource "google_org_policy_policy" "legacy_sa_keys" {
  name   = "${google_folder.this["legacy"].name}/policies/iam.disableServiceAccountKeyCreation"
  parent = google_folder.this["legacy"].name

  spec {
    rules {
      enforce = "FALSE"
    }
  }
}

# TECH-DEBT TD-003: These key rings were originally declared as flat resources in a
# 2023 "big bang" root module. `moved` blocks let us refactor into modules without
# destroying keys (destroying a key = crypto-shredding the data!).
# Moved blocks whose "from" address isn't in state are no-ops, so this is safe.
moved {
  from = google_kms_key_ring.audit_logs
  to   = module.logging_cmek.google_kms_key_ring.this
}

# TECH-DEBT TD-014: The data-platform bucket below was created by hand (ClickOps)
# during a 2024 incident. Bring it under management with an import block, then
# remove the import block in the following release.
#
# Uncomment once the bucket name is confirmed in the target org:
#
# import {
#   to = google_storage_bucket.clickops_incident_exports
#   id = "adv-prd-incident-exports-2024"
# }
#
# resource "google_storage_bucket" "clickops_incident_exports" {
#   name                        = "adv-prd-incident-exports-2024"
#   project                     = "adv-prd-dataplatform"
#   location                    = "EU"
#   uniform_bucket_level_access = true
#   public_access_prevention    = "enforced"
# }
