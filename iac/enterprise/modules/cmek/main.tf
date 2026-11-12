/**
 * Module: cmek
 *
 * A key ring with one or more customer-managed keys, plus IAM for the Google
 * service agents that encrypt and decrypt with them.
 *
 * Lives in the central KMS project (separation of duties: key admins are
 * not data admins).
 */

resource "google_kms_key_ring" "this" {
  project  = var.project_id
  name     = var.key_ring_name
  location = var.location
}

resource "google_kms_crypto_key" "keys" {
  for_each = var.keys

  name            = each.key
  key_ring        = google_kms_key_ring.this.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = each.value.rotation_period

  # How long a destroyed key version stays recoverable. This is the delay
  # between "crypto-shred requested" and "data provably unreadable"
  # (see docs/02-problem-statement.md section 5). Document it in your DPIA.
  destroy_scheduled_duration = each.value.destroy_scheduled_duration

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = each.value.protection_level
  }

  labels = merge(var.labels, { data_domain = each.value.data_domain })

  lifecycle {
    prevent_destroy = true
  }
}

locals {
  encrypter_bindings = merge([
    for key_name, members in var.encrypters : {
      for m in members : "${key_name}|${m}" => { key = key_name, member = m }
    }
  ]...)
}

resource "google_kms_crypto_key_iam_member" "encrypters" {
  for_each = local.encrypter_bindings

  crypto_key_id = google_kms_crypto_key.keys[each.value.key].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = each.value.member
}
