---
title: GCP Fintech Architecture Playbook
description: Reference architectures for a regulated, real-time payment-fraud platform on Google Cloud.
hide:
  - navigation
  - toc
---

<div class="hero" markdown>

# GCP Fintech Architecture Playbook

<p class="hero-tagline">Reference architectures for a regulated, real-time payment-fraud platform on Google Cloud. One problem, five designs, and two production-style Infrastructure-as-Code blueprints.</p>

<p class="hero-author">Architecture and IaC by <strong>Kshitij Vengurlekar</strong></p>

[Explore the architectures](case-studies/01-fully-managed.md){ .md-button .md-button--primary }
[Read the problem statement](02-problem-statement.md){ .md-button }
[View the Terraform :fontawesome-brands-github:](https://github.com/KshitijV97/gcp-fintech-architecture-playbook/tree/main/iac){ .md-button }

</div>

<div class="stats" markdown>

<div markdown><span class="stat">5</span><span class="stat-label">end-to-end architectures</span></div>
<div markdown><span class="stat">60+</span><span class="stat-label">architecture diagrams</span></div>
<div markdown><span class="stat">7</span><span class="stat-label">regulatory regimes mapped</span></div>
<div markdown><span class="stat">2</span><span class="stat-label">validated IaC blueprints</span></div>

</div>

## The problem

> *Score every card and SEPA Instant payment for fraud in under 150 ms, keep a tamper-evident record of every decision, let customers see and dispute flagged payments, and let analysts improve fraud models, while meeting GDPR, PSD2, AML and DORA.*

**Project Sentinel** exercises nearly every layer of a cloud platform: streaming ingestion, low-latency serving, a strongly consistent ledger, analytics and ML, customer-facing APIs, and key management. It also carries a built-in regulatory conflict. GDPR's right to erasure collides with AML's 5–10-year retention, and the playbook resolves it with **crypto-shredding and legal-hold segregation**. [Read the full problem statement →](02-problem-statement.md)

## Five designs for the same workload

<div class="grid cards" markdown>

-   :material-cloud-check-outline:{ .lg .middle } **Case 1 · Fully managed**

    ---

    Cloud Run, Pub/Sub, Dataflow, Spanner, BigQuery, Vertex AI and Apigee: the fewest controls to evidence yourself, and the fastest route to production.

    [:octicons-arrow-right-24: Read the design](case-studies/01-fully-managed.md)

-   :material-kubernetes:{ .lg .middle } **Case 2 · Semi-managed**

    ---

    GKE, Managed Kafka, AlloyDB and Memorystore: open-source engines on Google-run control planes, giving a DORA exit strategy you can demonstrate.

    [:octicons-arrow-right-24: Read the design](case-studies/02-semi-managed.md)

-   :material-server-security:{ .lg .middle } **Case 3 · Least managed**

    ---

    Compute Engine on sole-tenant nodes with self-run Kafka, Flink, Patroni and Vault: maximum control, and the full cost of owning every layer.

    [:octicons-arrow-right-24: Read the design](case-studies/03-least-managed.md)

-   :material-transit-connection-variant:{ .lg .middle } **Case 4 · Hybrid & multi-cloud**

    ---

    Mainframe, Interconnect, Confluent, an external key manager (Thales via EKM), AWS, Azure and SaaS, plus a privacy command bus across all of them.

    [:octicons-arrow-right-24: Read the design](case-studies/04-hybrid-multicloud.md)

-   :material-map-marker-radius-outline:{ .lg .middle } **Case 5 · Canada & PIPEDA**

    ---

    Why PIPEDA is not a subset of GDPR: a seven-point gap analysis, a Canadian data cell in Montréal and Toronto, and evidence for each principle.

    [:octicons-arrow-right-24: Read the design](case-studies/05-canada-pipeda.md)

-   :material-scale-balance:{ .lg .middle } **Comparison & decision guide**

    ---

    Cost, team size, latency, portability, key sovereignty and erasure difficulty, side by side, with a decision flow.

    [:octicons-arrow-right-24: Compare](04-comparison.md)

</div>

## Infrastructure as Code

<div class="grid cards" markdown>

-   :material-bank-outline:{ .lg .middle } **Enterprise blueprint: Aldervane Bank**

    ---

    - Landing zone with EU and Canada cells, Assured Workloads, VPC Service Controls, CMEK/HSM and a locked audit trail
    - OPA policy-as-code and a **CAB-gated change pipeline** with ServiceNow
    - Demand management and a **CI-enforced tech-debt register**

    [:octicons-arrow-right-24: Walkthrough](iac/05-enterprise-iac.md)

-   :material-rocket-launch-outline:{ .lg .middle } **Startup blueprint: Quillpay**

    ---

    - Keyless GitHub Actions through Workload Identity Federation
    - One reusable jurisdiction-cell module, deployed for the EU and Canada
    - Privacy registers (consent, disclosure, breach, DSR) built in from day one

    [:octicons-arrow-right-24: Walkthrough](iac/06-startup-iac.md)

</div>

## Engineering operating model

<div class="grid cards" markdown>

-   :material-source-repository-multiple:{ .lg .middle } **Repository strategy**

    ---

    A product monorepo for the startup and a governed polyrepo for the bank, with branching, CODEOWNERS, module versioning and GitOps promotion.

    [:octicons-arrow-right-24: Read](engineering/11-repository-strategy.md)

-   :material-robot-outline:{ .lg .middle } **Agentic SDLC**

    ---

    A deliverable per session, not a release per sprint: risk-tiered agent autonomy, compliance evidence from every session, DORA metrics.

    [:octicons-arrow-right-24: Read](engineering/12-agentic-sdlc.md)

-   :material-cog-transfer-outline:{ .lg .middle } **Agent platform**

    ---

    Claude Code on Vertex AI (EU) with hooks, subagents and skills, plus OpenCode and OpenHands on self-hosted GLM as a tested exit path.

    [:octicons-arrow-right-24: Read](engineering/13-agent-platform.md)

</div>

## Governance and assurance

<div class="grid cards" markdown>

-   :material-database-search-outline:{ .lg .middle } **Data governance**

    ---

    Dataplex Universal Catalog, Sensitive Data Protection and BigQuery policy tags, plus OpenMetadata for the multi-cloud estate.

    [:octicons-arrow-right-24: Read](08-data-governance.md)

-   :material-file-certificate-outline:{ .lg .middle } **Evidence register**

    ---

    Every control mapped to its implementation and its proof, with Log Analytics queries and hash-sealed evidence packs.

    [:octicons-arrow-right-24: Read](10-evidence-register.md)

-   :material-format-list-checks:{ .lg .middle } **Compliance controls map**

    ---

    GDPR, PSD2, AML, DORA and EBA outsourcing requirements mapped to Org Policies, perimeters, keys and detection.

    [:octicons-arrow-right-24: Read](03-compliance-controls.md)

</div>

## Engineering quality

| Gate | How it is enforced |
|---|---|
| Terraform | Validated against `hashicorp/google` **v8.11**, format-checked in CI |
| Policy-as-code | OPA/Rego strict-checked; guardrails for residency, CMEK, public access, change risk |
| Documentation | Built with `mkdocs build --strict`, so any broken link or anchor fails the deploy |
| Delivery | Every push to `main` deploys to production; every pull request gets a preview URL |

<div class="footnote-reader" markdown>

New to the domain? The [approach and conventions](00-how-to-read.md) page defines the management spectrum and shared-responsibility model used throughout, and the [glossary](99-glossary.md) decodes the acronyms.

</div>
