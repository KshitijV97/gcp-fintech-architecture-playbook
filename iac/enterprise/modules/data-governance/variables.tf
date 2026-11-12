variable "project_id" {
  description = "Data/analytics project of the jurisdiction cell."
  type        = string
}

variable "jurisdiction" {
  type = string

  validation {
    condition     = contains(["eu", "ca"], var.jurisdiction)
    error_message = "jurisdiction must be eu or ca."
  }
}

variable "bq_location" {
  description = "BigQuery / taxonomy location: 'eu' for the EU cell, 'northamerica-northeast1' for Canada."
  type        = string
}

variable "dataplex_location" {
  description = "Region for Dataplex resources."
  type        = string
}

variable "sdp_location" {
  description = "Region for Sensitive Data Protection resources."
  type        = string
}

variable "analyst_group" {
  description = "Group that sees MASKED values, e.g. group:fraud-analysts@aldervane.example."
  type        = string
}

variable "raw_pii_readers" {
  description = "Principals allowed to read raw tagged columns (DSR executor SA, investigators)."
  type        = list(string)
  default     = []
}

variable "governance_dataset_id" {
  description = "Existing dataset that receives SDP data profiles."
  type        = string
}

variable "decisions_table" {
  description = "projects/P/datasets/D/tables/T of the decisions table to quality-check. null = skip."
  type        = string
  default     = null
}

variable "info_types" {
  description = "SDP infoTypes to detect. Defaults cover EU and Canadian identifiers."
  type        = list(string)
  default = [
    "PERSON_NAME",
    "EMAIL_ADDRESS",
    "PHONE_NUMBER",
    "IBAN_CODE",
    "CREDIT_CARD_NUMBER",
    "IP_ADDRESS",
    "DATE_OF_BIRTH",
    "PASSPORT",
    "CANADA_SOCIAL_INSURANCE_NUMBER",
    "CANADA_BANK_ACCOUNT",
    "GERMANY_IDENTITY_CARD_NUMBER",
  ]
}
