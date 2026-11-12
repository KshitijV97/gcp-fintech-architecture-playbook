# Quillpay guardrails: a lean subset of the enterprise policies.
# Run: conftest test plan.json --policy iac/startup/policies
package main

import rego.v1

changed contains rc if {
	some rc in input.resource_changes
	some a in rc.change.actions
	a in {"create", "update"}
}

jurisdiction(rc) := j if {
	j := rc.change.after.labels.jurisdiction
} else := "eu"

in_jurisdiction("eu", loc) if startswith(lower(loc), "europe-")

in_jurisdiction("eu", loc) if lower(loc) in {"eu", "global"}

in_jurisdiction("ca", loc) if startswith(lower(loc), "northamerica-northeast")

in_jurisdiction("ca", loc) if lower(loc) == "global"

deny contains msg if {
	some rc in changed
	some attr in ["location", "region"]
	loc := rc.change.after[attr]
	is_string(loc)
	not in_jurisdiction(jurisdiction(rc), loc)
	msg := sprintf("[RESIDENCY] %s: %s '%s' is outside the '%s' jurisdiction cell.", [rc.address, attr, loc, jurisdiction(rc)])
}

deny contains msg if {
	some rc in changed
	contains(rc.type, "_iam_")
	rc.change.after.member in {"allUsers", "allAuthenticatedUsers"}
	msg := sprintf("[PUBLIC] %s makes a resource public.", [rc.address])
}

deny contains msg if {
	some rc in changed
	rc.type == "google_storage_bucket"
	not rc.change.after.encryption
	not rc.change.after_unknown.encryption
	msg := sprintf("[CMEK] %s must use a customer-managed key.", [rc.address])
}

deny contains msg if {
	some rc in changed
	rc.type == "google_storage_bucket"
	contains(rc.change.after.name, "breach-records")
	rc.change.after.retention_policy[0].retention_period < 63072000
	msg := sprintf("[PIPEDA-BREACH] %s: breach records must be retained ≥ 24 months.", [rc.address])
}
