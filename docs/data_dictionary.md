# Data dictionary and entity contracts

This dictionary covers all columns in the 11 core source entities. `InferredType` is sampled from up to 200 rows and is a convenience for review, not a substitute for SQL Server type contracts. See `docs/source_to_target_mapping_draft.csv` and the SQL DDL for transformation-level mapping.

## Entities and grain

| Entity | Source row count | Expected source grain | Primary data-quality note |
|---|---:|---|---|
| `Accounts` | 500 | One row per AccountID | AccountID should be unique; profile shows no duplicate keys. |
| `Activities` | 40,000 | One row per ActivityID | ActivityID is unique; foreign keys may be absent or unmatched. |
| `Campaigns` | 30 | One row per CampaignID | Campaign metadata; campaign budget currency is unverified. |
| `Contacts` | 1,500 | One row per ContactID | Contact-to-account relationship; avoid exposing personal contact fields to broad AI roles. |
| `Date` | 1,096 | One row per calendar date | Calendar spans 2024-01-01 to 2026-12-31. |
| `Leads` | 5,000 | One row per LeadID | Status-based conversion only; no explicit lead-opportunity bridge. |
| `Opportunities` | 15,000 | Expected one row per resolved OpportunityID | 35 duplicate IDs / 70 conflicting rows quarantined; Unknown stage excluded from trusted KPIs. |
| `OpportunityProducts` | 28,911 | One source product-line row; no stable line ID provided | 203 repeated OpportunityID + ProductID pairs (406 rows) preserved; do not dedupe on pair. |
| `Products` | 100 | One row per ProductID | Product line revenue/cost semantics need validation. |
| `SalesReps` | 50 | One row per SalesRepID | Annual targets need year-aware reconciliation; 2026 target period is partial. |
| `Targets` | 1,650 | One row per Month + SalesRepID | Monthly grain unique; available months are 2024-01 to 2026-09. |

## Critical measure contracts

- **Won revenue:** sum `Opportunities.EstimatedRevenue` only for trusted `Closed Won` records, attributed to `ActualCloseDate` month.
- **Open pipeline:** `EstimatedRevenue` for trusted opportunities in Qualification, Needs Analysis, Proposal, or Negotiation with positive revenue and valid 0–100 probability.
- **Weighted pipeline:** eligible open pipeline × `ProbabilityPct / 100`; not a calibrated forecast.
- **Win rate:** Closed Won / (Closed Won + Closed Lost), using dated outcomes and recomputing from counts at aggregate level.
- **Lead conversion:** `Status = Converted` divided by leads created in cohort; not revenue conversion.
- **Product line margin:** provisional `(LineRevenue - EstimatedCost) / LineRevenue`; not authoritative won revenue.

## Full column-level dictionary

See [`data_dictionary.csv`](data_dictionary.csv) for every source column, sampled type, definition, usage, observed null count in the sample and source filename.
