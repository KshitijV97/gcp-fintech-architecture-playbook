# Case 5 · Crossing the Atlantic: Sentinel Goes to Canada (PIPEDA)

> 🚀 **Primary protagonist: Quillpay**, which is launching instant payments for Canadian small businesses. 🏦 **Aldervane Bank** is opening "Aldervane Canada" at the same time, as a federally regulated bank. Both reuse Sentinel and both ask the same question:
>
> *"We're GDPR-compliant. Isn't that automatically PIPEDA-compliant?"*
>
> Short answer: **no**. PIPEDA overlaps heavily with GDPR but it is **not a subset**. This chapter finds the gaps, closes them, and shows the evidence for each.

> ⚖️ Summary for architectural purposes, **not legal advice**. PIPEDA is the *Personal Information Protection and Electronic Documents Act* (Canada's federal private-sector privacy law). Bill C-27 (the proposed Consumer Privacy Protection Act) died when Parliament was prorogued in January 2025. Watch for a successor bill, which could change the details below.

---

## 1. Who regulates what in Canada?

```mermaid
flowchart TB
    subgraph Privacy["Privacy"]
        PIPEDA["PIPEDA<br/>federal private sector<br/>10 fair information principles"]
        BSSR["Breach of Security<br/>Safeguards Regulations"]
        QC["Quebec Law 25<br/>provincial; stricter in places"]
    end
    subgraph Financial["Financial"]
        FINTRAC["PCMLTFA / FINTRAC<br/>AML records ≥ 5 years"]
        OSFI["OSFI B-10 third-party risk<br/>B-13 technology and cyber<br/>E-21 operational resilience"]
        RPAA["Retail Payment Activities Act<br/>Bank of Canada supervision of PSPs"]
    end
    QP["🚀 Quillpay Canada<br/>payment service provider"] --> PIPEDA & BSSR & QC & FINTRAC & RPAA
    AC["🏦 Aldervane Canada<br/>federally regulated bank"] --> PIPEDA & BSSR & QC & FINTRAC & OSFI
```

| Entity | Privacy | Prudential / conduct | AML |
|---|---|---|---|
| 🚀 Quillpay (payment service provider) | PIPEDA (+ Quebec Law 25 for Quebec customers) | **RPAA**: register with the Bank of Canada; operational-risk and incident-response framework; notify incidents | FINTRAC (MSB registration) |
| 🏦 Aldervane Canada (bank) | PIPEDA (+ Quebec Law 25) | **OSFI B-10, B-13, E-21**; technology and cyber incident reporting to OSFI (within 24 h per OSFI's advisory) | FINTRAC |

## 2. Is PIPEDA a subset of GDPR? The gap analysis

### 2.1 Where GDPR already covers PIPEDA (reuse it)

| PIPEDA principle (Schedule 1) | Covered by existing GDPR control | Reuse |
|---|---|---|
| 4.1 Accountability | DPO, RoPA, processor contracts | ✅ but a named **Privacy Officer** is needed for Canada |
| 4.2 Identifying purposes | Art. 13/14 notices, purpose limitation | ✅ |
| 4.4 Limiting collection | Art. 5(1)(c) minimisation, tokenisation at ingestion | ✅ |
| 4.5 Limiting use, disclosure, retention | Art. 5(1)(b),(e), retention engine, crypto-shredding | ⚠️ partly (see gaps 3 and 4) |
| 4.6 Accuracy | Art. 5(1)(d), Art. 16 rectification, Dataplex quality scans | ✅ |
| 4.7 Safeguards | Art. 32: CMEK, VPC-SC, IAM, logging | ✅ |
| 4.8 Openness | Art. 12–14 transparency | ✅ |
| 4.9 Individual access | Art. 15 access | ⚠️ partly (gap 4) |
| 4.10 Challenging compliance | DPO contact, right to complain to the supervisory authority | ⚠️ partly (gap 6) |

### 2.2 Where PIPEDA asks for something GDPR doesn't (close the gaps)

| # | PIPEDA requirement | What GDPR says | The gap |
|---|---|---|---|
| **G1** | **Consent is the default basis** (Principle 4.3). Meaningful consent, and **express** consent for sensitive information (financial data is generally sensitive). No general "legitimate interest" basis; only the specific exceptions in s.7 | Six lawful bases; fraud prevention can rest on **legitimate interest** (Recital 47) or legal obligation | Sentinel's EU design used legitimate interest. In Canada it needs **consent captured and evidenced**, or a documented s.7 exception |
| **G2** | **Record EVERY breach** of security safeguards and keep the record for **≥ 24 months** after determining the breach occurred (s.10.3 + Regulations). Fines for failing to record | Art. 33(5): document all breaches, **no fixed retention period** | Need a **24-month, tamper-evident breach register** |
| **G3** | Breach notification goes to the OPC **and** affected individuals when there is a **real risk of significant harm (RROSH)**, **and to any other organisation or government institution that can reduce the harm** (s.10.2), e.g. card issuers | Art. 33/34: supervisory authority within 72 h and individuals if high risk; no explicit duty to notify third parties | Add **third-party notification** step + RROSH assessment to the runbook. (GDPR's 72 h is stricter on timing, so keep it as the global SLA.) |
| **G4** | Access response must include an **account of how the information was used and the third parties it was disclosed to**, as specifically as possible (4.9.1, 4.9.3) | Art. 15(1)(c): recipients **or categories** of recipients | Need a **per-disclosure log** with named recipients, while **suppressing** disclosures that must not be revealed (FINTRAC reports: no tipping off; PIPEDA s.9(2.1)–(2.4)) |
| **G5** | Information **used to make a decision** about an individual must be **retained long enough for them to access it** (4.5.2). There is no general "right to erasure" | Art. 17 erasure; storage limitation pushes toward early deletion | **Minimum** retention floor for decision records, even after a withdrawal or deletion request |
| **G6** | Organisations must have **internal complaint-handling procedures**, investigate all complaints, and fix practices if a complaint is justified (4.10) | Complaint goes to the supervisory authority; internal process not mandated | Need an **internal complaint workflow** with evidence |
| **G7** | **Transfers outside Canada** are a "use" (OPC guidance): allowed without consent, but the organisation stays accountable and must **tell individuals** their data may be processed abroad and accessed by foreign authorities | Chapter V transfer mechanisms (adequacy, SCCs) | Notice + contracts for any EU access to Canadian data (e.g. Quillpay's EU-based support team) |
| **G8** | *(Quebec Law 25, for Quebec residents)*: a PIA **before** communicating data outside Quebec; notice when a decision is based **exclusively on automated processing**; a confidentiality-incident register; privacy by default | Similar ideas in GDPR Art. 22, 25, 35 | PIA for transfers outside Quebec; Art. 22-style notices reused; the incident register is already covered by G2 |

> **And the reverse:** GDPR has things PIPEDA lacks (an explicit right to erasure and to portability, Art. 22 rights, the 72-hour deadline, mandatory DPIAs, fines up to 4%). The Canadian cell keeps **all** the GDPR controls. Operating to the **union** of both regimes is simpler than maintaining two rulebooks.

```mermaid
flowchart LR
    subgraph GDPR_only["GDPR stricter"]
        A1["Explicit erasure right"]
        A2["Portability"]
        A3["72-hour breach clock"]
        A4["Art. 22 automated decisions"]
        A5["Mandatory DPIA"]
    end
    subgraph Both["Common core: reuse"]
        B1["Purpose limitation"]
        B2["Minimisation"]
        B3["Safeguards"]
        B4["Access and correction"]
        B5["Accountability"]
    end
    subgraph PIPEDA_only["PIPEDA adds"]
        C1["G1 consent-centric"]
        C2["G2 24-month breach records"]
        C3["G3 notify orgs that can reduce harm"]
        C4["G4 named disclosure accounting"]
        C5["G5 retention floor for decisions"]
        C6["G6 internal complaints"]
        C7["G7 foreign-processing notice"]
    end
    Both --> UNION["Union of both regimes =<br/>Sentinel global privacy baseline"]
    GDPR_only --> UNION
    PIPEDA_only --> UNION
```

## 3. Architecture: the Canadian data cell

Sentinel moves from "one platform" to a **cell-based** design: shared code, pipelines and container images, but **separate data planes per jurisdiction**.

```mermaid
flowchart TB
    subgraph Global["Global control plane: no personal data"]
        GH["GitHub + CI<br/>same Terraform modules"]
        AR["Container images<br/>signed, scanned"]
        MODEL["Model training code<br/>trained separately per cell"]
    end

    subgraph EU["🇪🇺 EU cell · europe-west3 · GDPR"]
        EU_RUN["Cloud Run scoring"]
        EU_SQL[("Ledger")]
        EU_BQ[("BigQuery + privacy registers")]
        EU_KMS["KMS: EU keys"]
    end

    subgraph CA["🇨🇦 Canadian cell · northamerica-northeast1 Montréal · DR northeast2 Toronto · PIPEDA"]
        CA_EDGE["API edge<br/>Interac / card networks"]
        CA_RUN["Cloud Run scoring<br/>JURISDICTION=ca"]
        CA_SQL[("Cloud SQL ledger<br/>backups in Toronto")]
        CA_PS["Pub/Sub<br/>storage policy: CA only"]
        CA_BQ[("BigQuery: analytics +<br/>consent_ledger, disclosure_log,<br/>breach_register, dsr_log")]
        CA_BR[("GCS breach-records<br/>locked 36 months")]
        CA_KMS["KMS: CA keys, HSM"]
        CA_CONS["Consent service<br/>express consent at onboarding"]
        CA_DSR["Access request orchestrator<br/>30-day SLA + disclosure account"]
    end

    GH --> EU & CA
    AR --> EU_RUN & CA_RUN
    CA_EDGE --> CA_RUN --> CA_SQL
    CA_RUN --> CA_PS --> CA_BQ
    CA_CONS --> CA_BQ
    CA_DSR --> CA_BQ & CA_SQL
    CA_KMS -.-> CA_SQL & CA_BQ & CA_PS & CA_BR
    EU -.-|"no replication of<br/>personal information"| CA
```

**Why a separate cell when PIPEDA allows cross-border transfers?**
1. **Customer and partner expectations:** Canadian banks and Interac participants expect Canadian residency.
2. **OSFI B-10 / B-13 (Aldervane):** simpler third-party risk and concentration analysis.
3. **Quebec Law 25:** a PIA is required before data leaves Quebec. Keeping data in Montréal and Toronto still means leaving Quebec for Toronto backups, so the PIA covers Toronto explicitly.
4. **Blast radius:** an incident in one cell doesn't become a multi-jurisdiction breach.

### Implemented in IaC

| Cell | Enterprise (Aldervane) | Startup (Quillpay) |
|---|---|---|
| Folder + residency guardrail | `fldr-ca-prod` with `gcp.resourceLocations` = Montréal + Toronto ([landing-zone/main.tf](https://github.com/KshitijV97/gcp-fintech-architecture-playbook/blob/main/iac/enterprise/landing-zone/main.tf)) | `prod-ca` folder ([bootstrap/main.tf](https://github.com/KshitijV97/gcp-fintech-architecture-playbook/blob/main/iac/startup/bootstrap/main.tf)) |
| Assured Workloads | `CA_REGIONS_AND_SUPPORT` (data location + support personnel) | Optional |
| Separate keys | `kms_ca` project | `qp-prod-ca-kms` project |
| Shift-left residency check | `RESIDENCY-CA` rule ([policies/residency.rego](https://github.com/KshitijV97/gcp-fintech-architecture-playbook/blob/main/iac/enterprise/policies/residency.rego)) | `[RESIDENCY]` rule ([policies/guardrails.rego](https://github.com/KshitijV97/gcp-fintech-architecture-playbook/blob/main/iac/startup/policies/guardrails.rego)) |
| Platform | Sentinel workload with `jurisdiction = "ca"` | [envs/prod-ca/main.tf](https://github.com/KshitijV97/gcp-fintech-architecture-playbook/blob/main/iac/startup/envs/prod-ca/main.tf) |
| Privacy registers | Data-governance module + registers | [modules/platform/privacy_tables.tf](https://github.com/KshitijV97/gcp-fintech-architecture-playbook/blob/main/iac/startup/modules/platform/privacy_tables.tf) |
| Breach records ≥ 24 months | Locked log bucket | Locked `breach-records` bucket (36 months), policy `[PIPEDA-BREACH]` |
| Demand | [dmd-0057](https://github.com/KshitijV97/gcp-fintech-architecture-playbook/blob/main/iac/enterprise/demand-management/demands/dmd-0057-sentinel-canada.yaml) | n/a |

## 4. Closing each gap

### G1: consent-centric design

```mermaid
sequenceDiagram
    autonumber
    actor C as Customer (Canada)
    participant App as Onboarding app
    participant CS as Consent service
    participant CL as BigQuery consent_ledger
    participant S as Scoring (Cloud Run)

    App->>C: Plain-language notice v3.2-CA: fraud screening is a condition of the service,<br/>optional: share fraud signals with partner banks
    C->>App: Accepts service terms (express), opts in to sharing
    App->>CS: record(customer_token, purposes, notice_version, channel)
    CS->>CL: INSERT GRANTED fraud_screening EXPRESS<br/>INSERT GRANTED consortium_sharing EXPRESS
    Note over S,CL: At scoring time
    S->>CS: may I use purpose=consortium_sharing for token X?
    CS-->>S: yes (cached 5 min)
    C->>App: Later: withdraws consortium_sharing
    App->>CS: withdraw
    CS->>CL: INSERT WITHDRAWN consortium_sharing
    CS--)S: cache invalidation → sharing stops for X
```

- **Fraud screening** is **reasonable and necessary** for a payment service, so it may be a *condition of service* (Principle 4.3.3) but must be stated clearly. For **sharing with other institutions** to prevent fraud, PIPEDA s.7(3)(d.2) permits disclosure without consent; Quillpay still asks for opt-in for consortium sharing as a trust choice.
- **Evidence:** the `consent_ledger` row with `notice_version`, plus the notice text versioned in Git.

### G2 + G3: breach register and notifications

```mermaid
flowchart TD
    D(["SCC / SecOps detection or staff report"]) --> T["Triage: is it a breach of<br/>security safeguards?"]
    T -->|"Yes"| R["Write breach_register row<br/>+ evidence to locked bucket<br/>ALWAYS, even if not reportable"]
    R --> J{"Jurisdiction of<br/>affected people?"}
    J -->|"EU"| G["GDPR risk assessment<br/>→ lead SA within 72 h if risk<br/>→ individuals if high risk"]
    J -->|"CA"| P{"RROSH?<br/>sensitivity × probability of misuse"}
    P -->|"Yes"| P1["Report to OPC as soon as feasible<br/>+ notify individuals directly<br/>+ notify orgs that can reduce harm (s.10.2)"]
    P -->|"Yes, Quebec residents"| Q1["Also notify CAI (Law 25)"]
    P -->|"No"| P2["Record only; keep ≥ 24 months"]
    J -->|"CA, Aldervane"| O["OSFI technology/cyber incident report<br/>per OSFI advisory"]
    J -->|"CA, Quillpay"| B["Bank of Canada RPAA incident notice"]
    G & P1 & Q1 & P2 & O & B --> U["Update breach_register:<br/>reported_to, timestamps, evidence_uri"]
```

- **Evidence:** `breach_register` table, the locked `*-breach-records` bucket (`retention_policy.is_locked = true`, 1096 days), and the conftest rule `[PIPEDA-BREACH]` that rejects any plan shortening it below 24 months.

### G4: access requests with a disclosure account

```mermaid
sequenceDiagram
    autonumber
    actor C as Customer
    participant DSR as Access orchestrator (Workflows)
    participant CAT as Dataplex catalog
    participant DL as disclosure_log
    participant LOG as dsr_log

    C->>DSR: Access request (authenticated)
    DSR->>LOG: INSERT received_at, due_at = +30 days
    DSR->>CAT: find assets for token (jurisdiction = ca)
    DSR->>DL: SELECT recipient_org, purpose, event_time<br/>WHERE suppress_from_access_response = FALSE
    Note over DSR,DL: Suppressed rows (e.g. FINTRAC STRs)<br/>are routed to Compliance for the<br/>s.9(2.1)–(2.4) process, never revealed
    DSR-->>C: Data export + how it was used + named third parties
    DSR->>LOG: status = COMPLETED, evidence_uri
```

### G5: retention floor vs. erasure ceiling

| Data | Floor (keep at least) | Ceiling (delete by) | Mechanism |
|---|---|---|---|
| Fraud decision records (CA) | Long enough for access after the decision. Policy: 2 years after the decision, or FINTRAC 5 years if the record is part of a transaction record | 5 years after the relationship ends, unless under legal hold | Retention engine + Object Retention Lock |
| Behavioural features | n/a | 13 months | BigQuery partition expiration |
| Consent ledger | Life of relationship + 2 years (proof of consent) | + 7 years | Partition expiration |
| Breach register | **24 months** (PIPEDA) | 36 months (policy) | Locked bucket |

> The erasure workflow from [Chapter 02](../02-problem-statement.md#5-the-central-puzzle-erasure-vs-retention) now checks **two** constraints: legal holds (AML) **and** the PIPEDA decision-access floor.

### G6: internal complaints

The DSR orchestrator accepts `request_type = COMPLAINT`. Each complaint goes to the **Privacy Officer** queue and must have an investigation outcome and, where justified, a linked remediation (a Jira or ServiceNow change). Monthly reporting on complaints goes to the Board risk committee.

### G7: foreign-processing notice

Quillpay's EU support engineers sometimes need read access to Canadian data during incidents. Controls:
1. The privacy notice states that information may be processed in the EU and may be accessible to authorities there.
2. Access goes through **IAM PAM** (just-in-time, time-boxed, justification required), and each grant is logged.
3. The intra-group data-transfer agreement is listed in the RoPA (`cross_border_transfer` field in the Dataplex `privacy-record` aspect).

## 5. Evidence pack: PIPEDA principle by principle

| Principle / provision | Control | Implementation | Evidence artifact | Frequency |
|---|---|---|---|---|
| 4.1 Accountability | Named Privacy Officer; processor contracts (Google, Interac partners) | Governance | Board appointment minute; Google Cloud DPA; vendor register | Annual |
| 4.1.3 Third-party processing | Contracts + residency + Assured Workloads | `CA_REGIONS_AND_SUPPORT`, folder location policy | Org-policy export, Assured Workloads compliance status | Quarterly via `collect-evidence.sh` |
| 4.2 Identifying purposes | Purpose catalogue in Dataplex aspect | `privacy-record` aspect `purpose` | Catalog export | Quarterly |
| 4.3 Consent | Consent service + ledger | `consent_ledger` table | Ledger sample + notice version in Git | Continuous / sampled monthly |
| 4.4 Limiting collection | Tokenisation at ingestion; SDP discovery | SDP discovery config | SDP profile findings = 0 raw identifiers in analytics | Monthly |
| 4.5 Retention (floor + ceiling) | Retention engine, partition expiry, object retention | `default_partition_expiration_ms`, `enable_object_retention` | Asset Inventory export of retention settings | Quarterly |
| 4.6 Accuracy | Dataplex data-quality scan | `dq-decisions-ca` | Scan results history | Daily |
| 4.7 Safeguards | CMEK (HSM), VPC-SC, IAM, no public IPs, audit logs | Platform module, org policies | KMS key inventory; perimeter config; SCC findings report | Monthly |
| 4.8 Openness | Public privacy policy (EN/FR) | Website | Archived policy versions | On change |
| 4.9 Access (30 days, disclosure account) | Access orchestrator | `dsr_log`, `disclosure_log` | SLA report: % within 30 days, extensions with notices | Monthly |
| 4.10 Challenging compliance | Complaint workflow | `dsr_log` `COMPLAINT` | Complaint register + outcomes | Monthly |
| s.10.1 Report RROSH breaches | Breach runbook | SecOps playbook | OPC report copies in breach-records bucket | Per incident |
| s.10.2 Notify orgs that can reduce harm | Runbook step | `third_parties_notified` | Breach register rows | Per incident |
| s.10.3 Record all breaches, 24 months | Locked register | `breach_records` bucket (locked, 1096 d) | `gcloud storage buckets describe` showing locked retention | Quarterly |
| Transfers (OPC guidance) | Notice + PAM + contracts | IAM PAM, aspect `cross_border_transfer` | PAM grant logs; transfer agreement | Quarterly |
| Quebec Law 25 | PIA, automated-decision notice, CAI notification | PIA-CA-2026-002 | PIA document; notice text | On change |

All automatable rows are collected by [`evidence/collect-evidence.sh`](https://github.com/KshitijV97/gcp-fintech-architecture-playbook/blob/main/evidence/collect-evidence.sh). See the full cross-regime register in [Chapter 10](../10-evidence-register.md).

## 6. Key takeaways

- ❌ **PIPEDA is not a subset of GDPR.** There is about 80% overlap, but the 20% (consent-centricity, 24-month breach records, named disclosure accounting, retention floors, internal complaints) is exactly what auditors test.
- ✅ **Design to the union** of regimes. One global privacy baseline, plus jurisdiction parameters (`jurisdiction = "ca"`) in the same Terraform modules.
- ✅ **Cells beat conditionals.** A separate Canadian data plane makes residency, keys, incidents and evidence clean and provable.
- ✅ **Evidence is a product feature.** Registers (consent, disclosure, breach, DSR) are tables with schemas, owners and retention, not spreadsheets.

➡️ Next: [10 · Evidence Register](../10-evidence-register.md)
