# Phase 1 Report — Requirements & Source Profiling

**Project:** Commercial Revenue Intelligence Data Warehouse & AI-Ready Analytics  
**Phase:** 1 of 8 — Requirements and source profiling  
**Status:** Initial profiling complete; business-rule validation and source-key decisions completed.

## Executive summary
The `CRM_Data.rar` archive contains **11 CSV files and 93,837 total rows** across accounts, contacts, leads, campaigns, opportunities, activities, products, opportunity-product lines, sales representatives, monthly targets, and a date dimension. Most tables have no exact duplicate rows and their apparent single-column IDs are unique. The main exception is `Opportunities.csv`: it has 15,000 rows but only 14,965 distinct OpportunityID values. **35 opportunity IDs each appear twice, and the paired records contain conflicting attributes.** This is a blocking issue for revenue, pipeline, and conversion metrics.

A second modeling issue is that `OpportunityProducts.csv` has 28,911 rows and 203 repeated `(OpportunityID, ProductID)` pairs (406 rows involved). Those pairs may be valid separate lines; the file has no line identifier to confirm. We must not delete them automatically.

The source also includes 120 opportunities without a sales rep, 180 without expected close dates, 1,793 without campaign IDs, 25 with Stage = `Unknown`, and 40 with zero estimated revenue. Null ActualCloseDate values are expected for open opportunities, but need to be checked against status rules.

## Dataset inventory
| Source | Rows | Columns | Exact duplicate rows | Notable observations |
|---|---:|---:|---:|---|
| Accounts | 500 | 10 | 0 | AccountID unique; no nulls detected |
| Contacts | 1,500 | 5 | 0 | ContactID unique; all AccountID values match Accounts |
| Campaigns | 30 | 6 | 0 | CampaignID unique |
| Date | 1,096 | 8 | 0 | 2024-01-01 to 2026-12-31; Date unique |
| Leads | 5,000 | 9 | 0 | LeadID unique; 3,606 null ConvertedDate values |
| Opportunities | 15,000 | 15 | 0 | 35 duplicated IDs / 70 rows; 120 null owners; 180 null expected close dates; 40 zero revenue; 25 Unknown stages |
| Activities | 40,000 | 8 | 0 | ActivityID unique; all tested foreign keys matched |
| OpportunityProducts | 28,911 | 6 | 0 | 203 repeated OpportunityID+ProductID pairs; no line ID |
| Products | 100 | 6 | 0 | ProductID unique; no nulls detected |
| SalesReps | 50 | 6 | 0 | SalesRepID unique; includes TargetAnnual |
| Targets | 1,650 | 5 | 0 | One row per Month + SalesRepID; 33 months from Jan 2024 to Sep 2026 |

## Key profiling results
- **Total rows:** 93,837.
- **Opportunity key integrity:** 35 duplicated ID values, each appearing twice; the duplicates differ across multiple business attributes.
- **Nulls:** concentrated in Leads.ConvertedDate (3,606), Opportunities.ActualCloseDate (10,216), Opportunities.CampaignID (1,793), Opportunities.ExpectedCloseDate (180), and Opportunities.SalesRepID (120). Several nulls may be legitimate depending on lifecycle state.
- **Foreign-key candidates:** all tested non-null child references matched their parent key values. However, Opportunities.SalesRepID has 120 nulls, Opportunities.CampaignID has 1,793 nulls, and duplicate OpportunityID values mean relationships to Opportunities are not yet safely one-to-many.
- **Date validity:** tested non-null date values parsed successfully. Main ranges: CRM-created dates start 2024-01-01; activity dates run 2024-01-01 through 2026-09-30; targets run monthly from 2024-01-01 through 2026-09-01; date dimension ends 2026-12-31.
- **ProbabilityPct:** values range 0–100 with no out-of-range values.
- **EstimatedRevenue:** 40 values are zero; no negative values observed.
- **Targets:** `Month + SalesRepID` is unique in the supplied data. `SalesReps.TargetAnnual` may overlap with monthly targets and requires definition.

## Relationship candidates checked
The following non-null key references matched: Contacts→Accounts; Activities→Opportunities/Accounts/SalesReps; Leads→Accounts/SalesReps; Opportunities→Accounts/SalesReps/Campaigns; OpportunityProducts→Opportunities/Products; Targets→SalesReps/Date. This is only a value-match check, not proof that all relationships should be enforced as database foreign keys. Duplicate OpportunityID values and null references still require handling.

## Phase 1 decisions
- Preserve all raw files unchanged in Bronze.
- Do not silently delete or arbitrarily select between duplicate opportunities. Quarantine the conflicting IDs and investigate source provenance.
- Do not treat `(OpportunityID, ProductID)` as a unique key without further evidence.
- Treat `ActualCloseDate` nulls as potentially expected for open opportunities, but validate against Stage.
- Use the `Targets` table as the candidate monthly target fact and keep `SalesReps.TargetAnnual` as a separate attribute until reconciled.
- Build the Gold layer around explicit facts and dimensions only after grain, status mapping, revenue definitions, and key treatment are approved.

## Phase 1 deliverables
- `profiling/table_profile.csv` — row/column counts and exact duplicate rows.
- `profiling/column_profile.csv` — data types, null counts, distinct counts, and sample values.
- `profiling/null_profile.csv` — fields with nulls.
- `profiling/candidate_key_profile.csv` — candidate key uniqueness checks.
- `profiling/date_profile.csv` — date parsing and ranges.
- `profiling/relationship_profile.csv` — candidate foreign-key checks.
- `profiling/duplicate_opportunity_records.csv` — all duplicated opportunity rows for review.
- `profiling/repeated_opportunity_product_pairs.csv` — repeated opportunity-product pairs.
- `profiling/business_rule_checks.csv` — selected semantic checks.
- `docs/business_requirements_and_kpi_glossary.md` — draft business questions and KPI definitions.
- `docs/source_to_target_mapping_draft.csv` — proposed mapping and open assumptions.
