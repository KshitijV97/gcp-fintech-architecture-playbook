# 07 · Roadmap: Implementation Phases

> ⚖️ Not legal or compliance advice. Regulations are paraphrased; organisations and people are fictional. [Disclaimer](disclaimer.md)

This repository grows in phases. Each phase ends in something **deployable and demonstrable**.

```mermaid
gantt
    title Implementation phases
    dateFormat YYYY-MM-DD
    axisFormat %b %Y
    section Phase 1 · Design
    Case studies, catalogue, IaC blueprints        :done, p1, 2026-11-01, 30d
    section Phase 2 · Startup track
    Bootstrap + platform module in sandbox org     :p2a, after p1, 21d
    Sample scoring service + rules engine          :p2b, after p2a, 21d
    DSR orchestrator (Workflows) + crypto-shredding :p2c, after p2b, 21d
    section Phase 3 · Enterprise track
    Landing zone end-to-end + Terratest            :p3a, after p2a, 30d
    Policy tests (conftest verify) in CI           :p3b, after p3a, 14d
    Sentinel on GKE + AlloyDB + Managed Kafka      :p3c, after p3b, 30d
    section Phase 4 · Advanced
    Canada cell + evidence automation job          :p4a, after p3c, 21d
    Hybrid: Confluent + EKM simulation             :p4b, after p4a, 30d
    DR drills, chaos testing, exit test            :p4c, after p4b, 21d
```

| Phase | Deliverables | Definition of done |
|---|---|---|
| **1 · Design** ✅ | Docs, diagrams, IaC blueprints | Reviewed, `terraform fmt`-clean |
| **2 · Startup track** | Deployed EU cell, sample app, DSR workflow with crypto-shredding | Erasure demo end to end; evidence pack generated |
| **3 · Enterprise track** | Landing zone, CAB-gated pipeline (mock ServiceNow), Sentinel Case 2 | Conftest unit tests (`conftest verify`), Terratest smoke tests |
| **4 · Advanced** | Canada cell, scheduled evidence job, hybrid simulation, DR and exit test | DORA-style test report |

## Backlog ideas

- `conftest verify` unit tests for every Rego rule, with sample plans
- A synthetic payments generator (Faker + Pub/Sub/Kafka load)
- A fraud model in BigQuery ML → Vertex AI, with explainability reason codes
- Renovate (or Dependabot) PRs for Terraform provider and action version bumps
- An OpenMetadata deployment on GKE for the hybrid case
- An architecture decision record (ADR) set under `docs/adr/`
