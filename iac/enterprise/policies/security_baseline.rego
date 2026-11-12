# Security baseline guardrails (GDPR Art. 32, PIPEDA Principle 4.7, PCI DSS, DORA).
package main

import rego.v1

# --- No public principals ----------------------------------------------------

public_members := {"allUsers", "allAuthenticatedUsers"}

is_iam(rc) if contains(rc.type, "_iam_")

deny contains msg if {
	some rc in changed
	is_iam(rc)
	rc.change.after.member in public_members
	msg := sprintf("[IAM-PUBLIC] %s grants access to %s.", [rc.address, rc.change.after.member])
}

deny contains msg if {
	some rc in changed
	is_iam(rc)
	some m in rc.change.after.members
	m in public_members
	msg := sprintf("[IAM-PUBLIC] %s grants access to %s.", [rc.address, m])
}

# --- No basic roles ------------------------------------------------------------

basic_roles := {"roles/owner", "roles/editor", "roles/viewer"}

deny contains msg if {
	some rc in changed
	is_iam(rc)
	rc.change.after.role in basic_roles
	msg := sprintf("[IAM-BASIC-ROLE] %s uses basic role %s. Use a predefined or custom role.", [rc.address, rc.change.after.role])
}

# --- Buckets -----------------------------------------------------------------

deny contains msg if {
	some rc in changed
	rc.type == "google_storage_bucket"
	not rc.change.after.uniform_bucket_level_access
	msg := sprintf("[GCS-UBLA] %s must enable uniform_bucket_level_access.", [rc.address])
}

deny contains msg if {
	some rc in changed
	rc.type == "google_storage_bucket"
	rc.change.after.public_access_prevention != "enforced"
	msg := sprintf("[GCS-PAP] %s must set public_access_prevention = \"enforced\".", [rc.address])
}

# --- CMEK everywhere -----------------------------------------------------------
# A value may be unknown at plan time (computed from another resource); then it
# appears in after_unknown instead of after. Both count as "set".

set_or_unknown(rc, attr) if rc.change.after[attr]

set_or_unknown(rc, attr) if rc.change.after_unknown[attr]

cmek_attr := {
	"google_pubsub_topic": "kms_key_name",
	"google_sql_database_instance": "encryption_key_name",
	"google_artifact_registry_repository": "kms_key_name",
	"google_bigquery_dataset": "default_encryption_configuration",
	"google_storage_bucket": "encryption",
	"google_alloydb_cluster": "encryption_config",
}

deny contains msg if {
	some rc in changed
	attr := cmek_attr[rc.type]
	not set_or_unknown(rc, attr)
	msg := sprintf("[CMEK] %s must be encrypted with a customer-managed key (%s).", [rc.address, attr])
}

# --- Governance labels on projects ---------------------------------------------

required_project_labels := {"cost_center", "data_classification", "owner", "demand_id"}

deny contains msg if {
	some rc in changed
	rc.type == "google_project"
	some label in required_project_labels
	not rc.change.after.labels[label]
	msg := sprintf("[LABELS] %s is missing mandatory label '%s'.", [rc.address, label])
}
