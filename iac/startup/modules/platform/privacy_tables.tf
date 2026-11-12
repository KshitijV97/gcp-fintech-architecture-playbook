/**
 * Privacy registers: the evidence tables auditors and regulators ask for.
 *
 *   consent_ledger  : PIPEDA Principle 4.3 (meaningful consent, withdrawal);
 *                     GDPR Art. 7(1) (demonstrate consent, where consent is the basis)
 *   disclosure_log  : PIPEDA Principle 4.9.3 (account of third-party disclosures in
 *                     access responses); GDPR Art. 15(1)(c) recipients
 *   breach_register : PIPEDA s.10.3 (record of ALL breaches, 24 months);
 *                     GDPR Art. 33(5) (document all breaches)
 *   dsr_log         : PIPEDA Principle 4.9 / s.8(3) 30-day response;
 *                     GDPR Art. 12(3) one-month response
 *
 * All are append-only by convention: writers get dataEditor on this dataset only
 * through the DSR / consent services, humans get read-only access. In prod, add
 * table snapshots on a schedule for tamper evidence.
 */

locals {
  common_fields = [
    { name = "event_time", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "event_id", type = "STRING", mode = "REQUIRED" },
    { name = "jurisdiction", type = "STRING", mode = "REQUIRED", description = "eu | ca | ca-qc" },
  ]

  privacy_tables = {
    consent_ledger = {
      description = "Every consent grant/withdrawal with the exact notice version shown."
      schema = concat(local.common_fields, [
        { name = "customer_token", type = "STRING", mode = "REQUIRED" },
        { name = "purpose", type = "STRING", mode = "REQUIRED", description = "e.g. fraud_screening, marketing, consortium_sharing" },
        { name = "action", type = "STRING", mode = "REQUIRED", description = "GRANTED | WITHDRAWN | REFUSED" },
        { name = "consent_form", type = "STRING", mode = "REQUIRED", description = "EXPRESS | IMPLIED | NOT_REQUIRED_EXCEPTION" },
        { name = "legal_reference", type = "STRING", mode = "NULLABLE", description = "e.g. GDPR 6(1)(f), PIPEDA 7(3)(d.2)" },
        { name = "notice_version", type = "STRING", mode = "REQUIRED" },
        { name = "channel", type = "STRING", mode = "REQUIRED" },
      ])
    }

    disclosure_log = {
      description = "Every disclosure of personal information to a third party (named organisation)."
      schema = concat(local.common_fields, [
        { name = "customer_token", type = "STRING", mode = "REQUIRED" },
        { name = "recipient_org", type = "STRING", mode = "REQUIRED" },
        { name = "recipient_country", type = "STRING", mode = "REQUIRED" },
        { name = "data_categories", type = "STRING", mode = "REPEATED" },
        { name = "purpose", type = "STRING", mode = "REQUIRED" },
        { name = "legal_reference", type = "STRING", mode = "REQUIRED" },
        { name = "suppress_from_access_response", type = "BOOL", mode = "REQUIRED", description = "TRUE for disclosures that must not be revealed (e.g. FINTRAC STR: no tipping off; PIPEDA s.9(2.1)-(2.4))" },
      ])
    }

    breach_register = {
      description = "Record of every breach of security safeguards, reportable or not."
      schema = concat(local.common_fields, [
        { name = "breach_id", type = "STRING", mode = "REQUIRED" },
        { name = "discovered_at", type = "TIMESTAMP", mode = "REQUIRED" },
        { name = "determined_at", type = "TIMESTAMP", mode = "REQUIRED", description = "When we determined a breach occurred; the PIPEDA 24-month clock starts here" },
        { name = "description", type = "STRING", mode = "REQUIRED" },
        { name = "data_categories", type = "STRING", mode = "REPEATED" },
        { name = "individuals_affected", type = "INT64", mode = "NULLABLE" },
        { name = "rrosh_assessment", type = "STRING", mode = "REQUIRED", description = "PIPEDA real risk of significant harm: sensitivity + probability of misuse" },
        { name = "gdpr_risk_assessment", type = "STRING", mode = "NULLABLE" },
        { name = "reported_to", type = "STRING", mode = "REPEATED", description = "OPC, CAI (Quebec), lead SA (EU), OSFI, Bank of Canada (RPAA)" },
        { name = "reported_at", type = "TIMESTAMP", mode = "NULLABLE" },
        { name = "individuals_notified_at", type = "TIMESTAMP", mode = "NULLABLE" },
        { name = "third_parties_notified", type = "STRING", mode = "REPEATED", description = "PIPEDA s.10.2: orgs that can reduce the risk of harm (e.g. card issuers)" },
        { name = "evidence_uri", type = "STRING", mode = "NULLABLE", description = "gs:// object in the locked breach-records bucket" },
      ])
    }

    dsr_log = {
      description = "Access, correction, erasure, withdrawal and complaint requests with SLA tracking."
      schema = concat(local.common_fields, [
        { name = "request_id", type = "STRING", mode = "REQUIRED" },
        { name = "customer_token", type = "STRING", mode = "REQUIRED" },
        { name = "request_type", type = "STRING", mode = "REQUIRED", description = "ACCESS | CORRECTION | ERASURE | PORTABILITY | CONSENT_WITHDRAWAL | COMPLAINT" },
        { name = "received_at", type = "TIMESTAMP", mode = "REQUIRED" },
        { name = "due_at", type = "TIMESTAMP", mode = "REQUIRED", description = "30 days (PIPEDA) / 1 month (GDPR), whichever is earlier" },
        { name = "extended_until", type = "TIMESTAMP", mode = "NULLABLE" },
        { name = "extension_notice_sent_at", type = "TIMESTAMP", mode = "NULLABLE" },
        { name = "status", type = "STRING", mode = "REQUIRED" },
        { name = "outcome_summary", type = "STRING", mode = "NULLABLE" },
        { name = "evidence_uri", type = "STRING", mode = "NULLABLE" },
      ])
    }
  }
}
