# Project Build Journal

This file is the running record for the GitHub README. Append one section at the end of each phase.

## Phase 1 — Requirements and source profiling
- **Status:** Initial profiling complete; business-rule and grain decisions complete.
- **Evidence:** 11 CSV files, 93,837 rows total.
- **Key findings:** 35 duplicated OpportunityID values (70 rows with conflicting attributes); 203 repeated OpportunityID+ProductID pairs (406 rows); 120 opportunities without SalesRepID; 180 without ExpectedCloseDate; 1,793 without CampaignID; 25 Unknown stages; 40 zero estimated revenue.
- **Key design risks:** opportunity key integrity, opportunity-product grain, Stage/ForecastCategory inconsistency, EstimatedRevenue versus LineRevenue semantics, monthly versus annual target definitions, absent opportunity history for true forecast backtesting.
- **Artifacts:** see `docs/phase1_source_profiling_report.md`, `docs/business_requirements_and_kpi_glossary.md`, `docs/source_to_target_mapping_draft.csv`, and `profiling/`.
- **What changed because of profiling:** no final DDL should assume OpportunityID is unique; no join should flatten opportunity-product or activity grain; source-to-target mapping remains provisional until revenue and status rules are agreed.
- **GitHub evidence:** committed profile outputs, mapping draft, KPI glossary, and decision log.

## Phase 2 — Architecture and repository setup
- Status: complete.
- Record chosen database platform/version, schemas, naming standards, architecture diagram, and rationale.

## Phase 3 — Bronze ingestion
- Status: complete.
- Record load strategy, raw table design, metadata columns, run logging, rerun/idempotency tests, and row-count reconciliation.

## Phase 4 — Silver transformations
- Status: complete.
- Record standardization rules, duplicate handling, exception/quarantine logic, data-quality tests, and before/after counts.

## Phase 5 — Gold dimensional model
- Status: complete.
- Record fact grain, dimension design, surrogate/business keys, relationships, date roles, and reconciliation evidence.

## Phase 6 — Commercial SQL analytics
- Status: complete.
- Record final KPI definitions, SQL views, test cases, sample outputs, and business interpretation.

## Phase 7 — AI-ready access layer
- Status: future work.
- Record approved views, glossary, supported questions, generated SQL validation, permissions, and limitations.


## Phase 3 — Bronze ingestion (artifacts prepared)
- Created raw table DDL for all 11 source entities using NVARCHAR(MAX) source columns and row-level lineage metadata.
- Added ingestion batch lifecycle procedures, source-file audit and error logging tables.
- Added manifest-driven Python CSV loader with dry-run, header/schema drift checks, row counts, error logging and append-only batches.

## Phase 4 — Silver transformations (prepared; database execution completed)
- Added typed Silver tables for Opportunities, SalesReps, and Targets, plus quality exception and target reconciliation control tables.
- Added stored procedure that trims strings, converts dates and numeric measures, normalizes known opportunity stage labels, quarantines all rows for duplicated opportunity keys, flags unknown stages and forecast-category mismatches, and reconciles monthly versus annual rep targets.
- Added quality query and a test plan. Bronze remains untouched.
- Important: this phase's SQL scripts are authored but not executed against a live SQL Server. Save actual execution outputs before calling Phase 4 complete.
- Currency caveat retained: AED is a requested reporting convention, not source-verified currency. Monthly target data through September 2026 is partial-year data.

## Phase 5 — Gold model (design and DDL)
- Defined conformed dimensions: customer/account, product, sales rep, campaign and date; added contact as a supporting dimension.
- Defined facts and grains: opportunity (one resolved opportunity), activity (one activity), opportunity product (one source line with surrogate key), lead (one lead), sales target (one rep-month).
- Added SQL Server DDL with surrogate keys and foreign keys where applicable, plus grain/orphan/aggregation validation queries.
- Won revenue remains based on `EstimatedRevenue` as requested; monetary columns are labelled AED.

## Phase 4 completion update — 

- Added typed Silver tables for Accounts, Activities, Campaigns, Contacts, CalendarDate, Leads, OpportunityProducts and Products.
- Added `slv.usp_TransformRemainingEntities` with transactional rebuilds, canonical status/boolean handling, date/numeric conversion, duplicate-key quarantine and row-level Bronze lineage.
- Added full Bronze-vs-Silver count and referential-integrity report at `sql/04_quality/210_phase4_full_reconciliation.sql`.
- Added offline source validator at `src/validation/validate_phase4_sources.py`.
- Offline source validation passed: 11 source CSVs, 93,837 rows, exact expected headers, zero malformed row widths; 35 duplicate OpportunityID values (70 rows in duplicate groups); 203 repeated OpportunityID/ProductID pairs (406 rows); zero duplicate target month/rep grains.
- Target source baseline: 2024 and 2025 annual values reconcile to monthly sums within AED 0.05 rounding tolerance for all 50 reps; 2026 is partial through September. Values are not overwritten to force equality.
- 
## Phase 6 — Commercial SQL analytics (2026-10-17)

**Prepared:** `rpt` KPI views for opportunity base, won revenue, open pipeline, weighted pipeline, win rate, target achievement, pipeline coverage, sales activity, lead conversion, product-line margin and opportunity ageing. Added KPI glossary, management SQL examples and edge-case test script.

**Metric decisions:** won revenue uses `EstimatedRevenueAED`; won revenue is attributed to actual close month; win rate uses closed wins divided by wins plus losses; target achievement aligns rep and actual-close month; pipeline coverage aligns rep and expected-close month; ageing is dynamic against SQL Server UTC date; lead conversion uses created cohort; product margin remains provisional.


## Phase 7 — AI-ready access layer
- Added nine stable business-named `rpt.ai_*` views over approved Phase 6 reporting views.
- Added least-privilege role grant template and smoke tests.
- Added JSON view registry, natural-language question examples, and expected output contracts.
- Added Python prototype with fixed query intents, parameterized SQL, input validation, result cap, and explain-only mode when no connection is configured.
