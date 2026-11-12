/**
 * Module: data-governance
 *
 * Google-native data governance for one jurisdiction cell (EU or CA):
 *
 *   1. Policy-tag taxonomy (column-level security in BigQuery)
 *   2. Dynamic data masking policies (SHA-256 / nullify) per tag
 *   3. Fine-grained reader grants (only privileged roles see raw PII)
 *   4. Dataplex Universal Catalog aspect type "privacy-record": a machine-readable
 *      Record of Processing (GDPR Art. 30) / PIPEDA Principle 4.1 + 4.8 openness
 *      attached to every data asset
 *   5. Sensitive Data Protection inspect template + discovery scan: continuously
 *      finds personal data, including data that "shouldn't be there"
 *   6. Dataplex data-quality scan on the decision table (GDPR Art. 5(1)(d) accuracy,
 *      PIPEDA Principle 4.6 accuracy)
 *
 * Verified against provider v8.11 docs (Nov 2026). Notes:
 *   - Only ONE SDP discovery config may exist per project/folder/org.
 *   - Dataplex aspect primitive types are string | int | bool | double | datetime.
 *   - BigQuery data policies reference policy tags by project NUMBER path
 *     (google_data_catalog_policy_tag.*.name already returns that form).
 */

# --- 1. Policy-tag taxonomy -------------------------------------------------------

resource "google_data_catalog_taxonomy" "privacy" {
  project                = var.project_id
  region                 = var.bq_location
  display_name           = "privacy-${var.jurisdiction}"
  description            = "Column classification for ${upper(var.jurisdiction)} personal data."
  activated_policy_types = ["FINE_GRAINED_ACCESS_CONTROL"]
}

resource "google_data_catalog_policy_tag" "personal" {
  taxonomy     = google_data_catalog_taxonomy.privacy.id
  display_name = "personal-data"
  description  = "Any personal data / personal information."
}

resource "google_data_catalog_policy_tag" "leaf" {
  for_each = {
    direct_identifier = "Name, email, phone, IBAN, account number."
    quasi_identifier  = "Postcode, birth year, device ID, IP address."
    government_id     = "Passport, national ID, Canadian SIN (restricted)."
    financial         = "Amounts, balances, payees."
  }

  taxonomy          = google_data_catalog_taxonomy.privacy.id
  parent_policy_tag = google_data_catalog_policy_tag.personal.id
  display_name      = replace(each.key, "_", "-")
  description       = each.value
}

# --- 2. Dynamic masking: analysts see hashed values, not raw identifiers -----------

resource "google_bigquery_datapolicy_data_policy" "mask" {
  for_each = {
    direct_identifier = "SHA256"
    quasi_identifier  = "SHA256"
    government_id     = "ALWAYS_NULL"
    financial         = "DEFAULT_MASKING_VALUE"
  }

  project          = var.project_id
  location         = var.bq_location
  data_policy_id   = "mask_${var.jurisdiction}_${each.key}"
  policy_tag       = google_data_catalog_policy_tag.leaf[each.key].name
  data_policy_type = "DATA_MASKING_POLICY"

  data_masking_policy {
    predefined_expression = each.value
  }
}

resource "google_bigquery_datapolicy_data_policy_iam_member" "masked_readers" {
  for_each = google_bigquery_datapolicy_data_policy.mask

  project        = var.project_id
  location       = var.bq_location
  data_policy_id = each.value.data_policy_id
  role           = "roles/bigquerydatapolicy.maskedReader"
  member         = var.analyst_group
}

# --- 3. Raw access only for privileged roles (e.g. DSR executor, fraud investigators)

resource "google_data_catalog_policy_tag_iam_member" "fine_grained" {
  for_each = toset(var.raw_pii_readers)

  policy_tag = google_data_catalog_policy_tag.personal.name
  role       = "roles/datacatalog.categoryFineGrainedReader"
  member     = each.value
}

# --- 4. Dataplex Universal Catalog: privacy aspect (machine-readable RoPA) ----------

resource "google_dataplex_aspect_type" "privacy_record" {
  project        = var.project_id
  location       = var.dataplex_location
  aspect_type_id = "privacy-record-${var.jurisdiction}"
  display_name   = "Privacy record (${upper(var.jurisdiction)})"
  description    = "Processing purpose, legal basis or consent, retention and owner for this asset."

  metadata_template = jsonencode({
    name = "privacy_record"
    type = "record"
    recordFields = [
      { name = "jurisdiction", type = "enum", index = 1, annotations = { displayName = "Jurisdiction" },
      enumValues = [{ name = "EU", index = 1 }, { name = "CA", index = 2 }], constraints = { required = true } },
      { name = "purpose", type = "string", index = 2, annotations = { displayName = "Processing purpose" }, constraints = { required = true } },
      { name = "legal_basis_or_consent", type = "string", index = 3, annotations = { displayName = "GDPR Art. 6 basis / PIPEDA consent or exception" }, constraints = { required = true } },
      { name = "retention", type = "string", index = 4, annotations = { displayName = "Retention rule" }, constraints = { required = true } },
      { name = "legal_hold", type = "bool", index = 5, annotations = { displayName = "Under legal hold" } },
      { name = "data_owner", type = "string", index = 6, annotations = { displayName = "Accountable data owner" }, constraints = { required = true } },
      { name = "ropa_id", type = "string", index = 7, annotations = { displayName = "RoPA / PIA reference" } },
      { name = "cross_border_transfer", type = "string", index = 8, annotations = { displayName = "Transfers outside jurisdiction (and safeguard)" } },
    ]
  })
}

# --- 5. Sensitive Data Protection: discover personal data everywhere ----------------

resource "google_data_loss_prevention_inspect_template" "pii" {
  parent       = "projects/${var.project_id}/locations/${var.sdp_location}"
  display_name = "pii-${var.jurisdiction}"
  description  = "Personal data detectors for ${upper(var.jurisdiction)}."

  inspect_config {
    min_likelihood = "LIKELY"

    dynamic "info_types" {
      for_each = var.info_types
      content {
        name = info_types.value
      }
    }
  }
}

resource "google_data_loss_prevention_discovery_config" "bigquery" {
  parent       = "projects/${var.project_id}/locations/${var.sdp_location}"
  location     = var.sdp_location
  display_name = "discover-bq-${var.jurisdiction}"
  status       = "RUNNING"

  # Full resource path required (projects/P/locations/L/inspectTemplates/ID); the
  # template resource's `name` attribute is only the template ID.
  inspect_templates = ["projects/${var.project_id}/locations/${var.sdp_location}/inspectTemplates/${google_data_loss_prevention_inspect_template.pii.name}"]

  targets {
    big_query_target {
      filter {
        other_tables {}
      }
    }
  }

  actions {
    export_data {
      profile_table {
        project_id = var.project_id
        dataset_id = var.governance_dataset_id
        table_id   = "sdp_profiles"
      }
    }
  }
}

# --- 6. Data quality on the decision table ----------------------------------------

resource "google_dataplex_datascan" "decisions_quality" {
  count = var.decisions_table == null ? 0 : 1

  project      = var.project_id
  location     = var.dataplex_location
  data_scan_id = "dq-decisions-${var.jurisdiction}"

  data {
    resource = "//bigquery.googleapis.com/${var.decisions_table}"
  }

  execution_spec {
    trigger {
      schedule {
        cron = "0 3 * * *"
      }
    }
  }

  data_quality_spec {
    rules {
      column      = "customer_token"
      dimension   = "COMPLETENESS"
      threshold   = 1.0
      description = "Every decision is linked to a (pseudonymous) subject, so DSRs can find it."
      non_null_expectation {}
    }
    rules {
      column      = "decision"
      dimension   = "VALIDITY"
      description = "Only valid decision codes."
      set_expectation {
        values = ["ALLOW", "CHALLENGE", "BLOCK"]
      }
    }
    rules {
      column      = "model_version"
      dimension   = "COMPLETENESS"
      threshold   = 1.0
      description = "Explainability: every decision records the model version (GDPR Art. 22)."
      non_null_expectation {}
    }
  }
}
