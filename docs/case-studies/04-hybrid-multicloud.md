# Case 4 · Hybrid and Multi-cloud: "The Real World Is Messy"

> ⚖️ Not legal or compliance advice. Regulations are paraphrased; organisations and people are fictional. [Disclaimer](../disclaimer.md)

> 🏦 **Protagonist: Aldervane Bank Group**, the whole group this time. The real picture:
>
> - **Core banking** stays on an IBM Z mainframe in Frankfurt for at least 5 more years.
> - Aldervane recently **acquired "Brightkey"**, a KYC/identity-verification fintech that runs entirely on **AWS**.
> - Group IT has a **Microsoft Entra ID** workforce directory and an enterprise agreement with **Microsoft** (Office 365, some Azure).
> - The SOC runs on **Splunk** under a 3-year contract.
> - The privacy office has standardised on **OneTrust** for consent and DSR intake.
> - The regulator expects a credible answer to DORA's **concentration-risk** questions.
>
> Priya (Head of Cloud Architecture) has to design Sentinel to fit this landscape, not an ideal one.

---

## 1. Design principles for hybrid

1. **Google Cloud is the "decisioning and analytics" platform.** It's where Sentinel runs.
2. **Systems of record stay where they are** (mainframe ledger, AWS KYC), integrated through events.
3. **One event backbone spanning all environments**: Confluent Cloud, since it runs on GCP, AWS and Azure with cluster linking.
4. **Keys never live with the data processor.** Google Cloud **External Key Manager** connects to an on-prem **Thales CipherTrust** HSM cluster.
5. **One identity plane for humans** (Entra ID through Workforce Identity Federation) and **no static keys for machines** (Workload Identity Federation to AWS and Azure).
6. **Open formats at every boundary** (Kafka, Iceberg, Parquet, OpenTelemetry), which serves as the DORA exit strategy.

## 2. Target architecture

```mermaid
flowchart TB
    subgraph ONPREM["🏢 Aldervane DC Frankfurt + Backup DC"]
        MF["IBM Z mainframe<br/>core banking ledger"]
        CDC["IBM CDC / Precisely<br/>change capture"]
        THALES["Thales CipherTrust<br/>HSM cluster: EKM"]
        F5["F5 / on-prem API edge"]
        GDC["Google Distributed Cloud<br/>connected: low-latency<br/>scoring fallback"]
    end

    subgraph GCP["☁️ Google Cloud · Assured Workloads EU"]
        direction TB
        subgraph G_EDGE["Edge"]
            APIGEE["Apigee hybrid<br/>runtime on GKE + on-prem"]
            ARMOR["Cloud Armor"]
        end
        subgraph G_DEC["Decision platform: GKE Enterprise fleet"]
            SCORE["scoring-svc"]
            VERTEX["Vertex AI endpoints<br/>+ Feature Store"]
        end
        subgraph G_DATA["Data platform"]
            SPAN[("Spanner<br/>decision ledger")]
            BQ[("BigQuery<br/>+ BigLake Iceberg")]
            OMNI["BigQuery Omni<br/>queries S3 in place"]
            DF["Dataflow"]
        end
        subgraph G_GOV["Governance"]
            EKM["Cloud EKM<br/>+ Key Access Justifications"]
            DPX["Dataplex<br/>catalog + lineage"]
            WF["Workflows<br/>DSR executor"]
            SCC["Security Command Center"]
        end
    end

    subgraph CONF["🔀 Confluent Cloud: dedicated clusters, EU"]
        CC_GCP["Cluster on GCP<br/>europe-west3"]
        CC_AWS["Cluster on AWS<br/>eu-central-1"]
        CFLINK["Confluent Flink<br/>stream joins"]
    end

    subgraph AWS["🟧 AWS eu-central-1 · Brightkey"]
        KYC["KYC service<br/>EKS"]
        S3[("S3: KYC evidence<br/>Object Lock")]
        DBX["Databricks<br/>identity-risk models"]
    end

    subgraph MSFT["🟦 Microsoft"]
        ENTRA["Entra ID<br/>workforce identity"]
        AZ["Azure: Power BI<br/>exec reporting"]
    end

    subgraph SAAS["🧩 SaaS"]
        ONETRUST["OneTrust<br/>consent + DSR intake"]
        SPLUNK["Splunk Cloud<br/>SIEM / SOC"]
        GH["GitHub Enterprise<br/>+ Terraform Cloud"]
        SNOW["ServiceNow<br/>ITSM, CAB"]
    end

    MF --> CDC -->|"Interconnect"| CC_GCP
    KYC --> CC_AWS
    CC_AWS <-->|"Cluster Linking<br/>Cross-Cloud Interconnect"| CC_GCP
    CC_GCP --> CFLINK --> CC_GCP
    CC_GCP --> SCORE
    CC_GCP --> DF --> BQ
    F5 --> APIGEE --> SCORE
    SCORE <--> VERTEX
    SCORE --> SPAN
    SCORE -.->|"fallback when WAN degraded"| GDC
    OMNI -.->|"read in place"| S3
    THALES <-->|"EKM over VPC / mTLS"| EKM
    EKM -.-> SPAN & BQ
    ENTRA -->|"Workforce Identity Federation"| GCP
    ONETRUST -->|"DSR webhook"| WF
    WF -->|"erase request event"| CC_GCP
    GCP -->|"Pub/Sub → Splunk HEC"| SPLUNK
    GH -->|"OIDC: Workload Identity Federation"| GCP
    SNOW -->|"change approval gate"| GH
    BQ -->|"authorised views"| AZ
    DBX -.->|"Delta Sharing / Iceberg"| BQ
```

## 3. Network topology

```mermaid
flowchart LR
    DC["🏢 Frankfurt DC"] ===|"Dedicated Interconnect<br/>2 × 10G, 2 metros"| NCC["Network Connectivity<br/>Center hub"]
    BDC["🏢 Backup DC"] ===|"Partner Interconnect"| NCC
    NCC --- HUB["GCP hub VPC<br/>Cloud NGFW Enterprise"]
    HUB --- SPOKE1["Spoke: sentinel-prod"]
    HUB --- SPOKE2["Spoke: analytics-prod"]
    HUB ===|"Cross-Cloud Interconnect<br/>10G"| AWSTGW["AWS Transit Gateway<br/>Brightkey VPCs"]
    HUB ---|"HA VPN backup"| AWSTGW
    HUB -.->|"Private Service Connect"| CONFL["Confluent Cloud<br/>PSC endpoint"]
    HUB -.->|"PSC"| GOOG["Google APIs<br/>restricted.googleapis.com"]
```

> 💡 **Cross-Cloud Interconnect** gives Google-provisioned private links straight into AWS, Azure, OCI or Alibaba. With it, traffic between GCP and Brightkey's AWS environment never touches the public internet, which keeps the DPIA's transfer analysis simple.

## 4. Request flow across clouds

```mermaid
sequenceDiagram
    autonumber
    participant MF as Mainframe
    participant CC as Confluent (GCP)
    participant CA as Confluent (AWS)
    participant KYC as Brightkey KYC (AWS)
    participant Score as scoring-svc (GKE)
    participant V as Vertex AI
    participant EKM as Cloud EKM
    participant TH as Thales (on-prem)
    participant SP as Spanner

    MF->>CC: payment event via CDC (≈ 20 ms over Interconnect)
    Note over CA,CC: Identity-risk score already<br/>replicated by Cluster Linking
    KYC-->>CA: identity_risk updated (earlier, async)
    CA-->>CC: mirrored topic kyc.identity_risk
    CC->>Score: consume payment + join identity_risk (Confluent Flink)
    Score->>V: predict
    V-->>Score: score
    Score->>SP: write decision
    SP->>EKM: (on cache miss) unwrap DEK
    EKM->>TH: wrap/unwrap with Key Access Justification
    TH-->>EKM: allowed (justification = CUSTOMER_INITIATED_ACCESS)
    SP-->>Score: committed
    Score->>CC: decision event
    CC->>MF: decision consumed by payment hub
```

> 🔑 **The sovereignty lever:** if Aldervane ever has to cut Google off, for legal reasons or as part of an exit, it **disables the key in Thales**. Every Sentinel dataset encrypted under EKM becomes unreadable *immediately*, including Google's own backups. Regulators find this a convincing supplementary measure, but it is also a **self-inflicted outage switch**. EKM availability now sits directly on the critical path.

## 5. Why each third-party / competitor component?

| Component | Chosen | Why not the GCP-native option? | Trade-off accepted |
|---|---|---|---|
| Event backbone | **Confluent Cloud** | Pub/Sub is GCP-only; the bank needs one backbone across mainframe, GCP and AWS with cluster linking and Flink | Extra vendor, extra DPA, extra cost |
| Key management | **Thales CipherTrust via Cloud EKM** | Cloud KMS/HSM keys reside in Google; group policy requires keys outside the CSP | EKM latency and availability risk; two HSM teams |
| Workforce identity | **Entra ID** | Already the group directory; Workforce Identity Federation avoids duplicating identities | Federation complexity, attribute mapping |
| SIEM | **Splunk Cloud** | 3-year contract, SOC playbooks already built | Log egress cost; Google SecOps evaluated for renewal |
| Consent / DSR intake | **OneTrust** | Privacy office standard across all channels | Integration via webhooks + Workflows |
| KYC models | **Databricks on AWS** (Brightkey) | Acquired company; migration not justified yet | Cross-cloud data sharing via Iceberg / Delta Sharing |
| Exec BI | **Power BI on Azure** | Group standard | Authorised views, no raw PII leaves GCP |
| CI/CD and IaC | **GitHub Enterprise + Terraform Cloud** | Group standard; multi-cloud IaC | OIDC federation to GCP, AWS and Azure |
| ITSM | **ServiceNow** | Change and incident management of record | Pipeline integration (see [enterprise IaC](../iac/05-enterprise-iac.md)) |
| Low-latency fallback | **Google Distributed Cloud connected** | Scoring must survive a WAN outage | Hardware in the DC |

## 6. GDPR DSR across clouds and SaaS

The hardest part of hybrid is **finding every copy**. A DSR now spans GCP, AWS, Confluent, Splunk, Databricks and the mainframe.

```mermaid
flowchart LR
    OT["OneTrust<br/>DSR intake + identity verification"] -->|"webhook"| WF["GCP Workflows<br/>DSR coordinator"]
    WF -->|"privacy.erase.v1 event"| CC["Confluent topic<br/>privacy-commands"]
    CC --> G1["GCP executor<br/>Spanner, BigQuery, Feature Store"]
    CC --> A1["AWS executor<br/>Lambda: S3, EKS DB, Databricks"]
    CC --> M1["Mainframe executor<br/>CICS transaction: restrict flag"]
    CC --> S1["Splunk executor<br/>delete via API on PII indices"]
    G1 & A1 & M1 & S1 -->|"privacy.erase.done.v1"| CC
    CC --> WF
    WF -->|"all done, evidence bundle"| OT
    DPX["Dataplex lineage<br/>+ RoPA"] -.->|"which systems hold subject data?"| WF
```

**Pattern: event-driven "privacy command bus".** Each system has an **executor** that owns deletion in its own domain and reports back with evidence. The coordinator tracks completion against the 30-day SLA.

## 7. Compliance mapping highlights

| Concern | Hybrid-specific answer |
|---|---|
| **International transfers** | All providers contracted for EU regions; AWS `eu-central-1`, Confluent EU, Splunk EU, OneTrust EU tenant. Transfer impact assessment for US-parent providers relies on the EU–US Data Privacy Framework plus SCCs, and on EKM so that the CSP has no access to keys |
| **Processor chain (Art. 28)** | DPAs with Google, AWS, Confluent, Splunk, OneTrust, Databricks, Microsoft; all listed in the RoPA |
| **DORA register of information** | Every ICT third party recorded with criticality, exit plan and substitutability |
| **DORA concentration risk** | Decisioning on GCP, KYC on AWS, ledger on-prem; no single CSP failure stops payments (rules-only fallback on GDC) |
| **Logging and SIEM** | GCP logs → Pub/Sub → Splunk HEC; AWS CloudTrail → Splunk; single SOC view |
| **Identity** | Entra ID conditional access + Workforce Identity Federation; GCP IAM PAM for just-in-time elevation |
| **Key custody** | EKM with Key Access Justifications: every Google access to a key carries a reason code that the Thales policy can deny |

## 8. Operations: who gets paged?

| Event | Who handles it |
|---|---|
| Interconnect link down | Network team; traffic fails over to the second metro or HA VPN |
| Thales EKM cluster unavailable | 🔥 **Sev-1.** Sentinel data becomes unreadable; HSM team and cloud team on a bridge call |
| Confluent cluster-link lag | Streaming platform team + Confluent support |
| AWS region issue | Brightkey team; Sentinel degrades to "identity risk unknown", scoring continues |
| GCP region issue | Spanner multi-region keeps going; GKE fleet fails over; GDC fallback scoring |

## 9. Cost and complexity

```mermaid
quadrantChart
    title "Control vs. operational simplicity"
    x-axis "Low control" --> "High control"
    y-axis "High ops burden" --> "Low ops burden"
    quadrant-1 "Sweet spot: rare"
    quadrant-2 "Managed convenience"
    quadrant-3 "Worst of both"
    quadrant-4 "Sovereign but heavy"
    Case 1 Managed: [0.25, 0.85]
    Case 2 Semi: [0.55, 0.55]
    Case 3 Least: [0.9, 0.15]
    Case 4 Hybrid: [0.75, 0.35]
```

Hybrid is rarely the cheapest option. It's the option that **fits the constraints you already have**. The biggest hidden costs:

- **Egress and interconnect** (cross-cloud data movement)
- **Integration engineering** (executors, schema registry, identity mapping)
- **Vendor management** (seven DPAs, seven sets of audit reports, seven exit plans)

## 10. Key takeaways

- ✅ Matches reality: legacy systems of record, acquisitions, existing contracts.
- ✅ Strong sovereignty (EKM) and a DORA concentration-risk story.
- ⚠️ **Complexity is the main risk.** Invest in a **privacy command bus**, **a single catalog and lineage view** (Dataplex for GCP, plus OpenMetadata across clouds; see [Chapter 08](../08-data-governance.md#when-google-native-isnt-enough-openmetadata-in-the-hybrid-case)), and **open formats**.
- ⚠️ Every external dependency on the critical path (EKM, Confluent, Interconnect) needs its own SLO, runbook and DR test.

➡️ Next: [04 · Comparison and Decision Guide](../04-comparison.md)
