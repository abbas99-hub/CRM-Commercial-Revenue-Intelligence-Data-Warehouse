# Phase 2 — Architecture and Repository Design

## Objective
Build a SQL-first commercial revenue warehouse with auditable ingestion, conformed business entities, governed KPI logic, and an AI-ready access layer.

## Bronze–Silver–Gold pattern

### Bronze (`brz` schema) — raw and replayable
- Load source rows with minimal transformation; preserve source values and nulls.
- Add `SourceSystem`, `SourceFileName`, `SourceRowNumber`, `IngestionBatchID`, `IngestedAtUtc`, and `RecordHash` metadata.
- Keep ingestion batch and file manifests; raw records are append-only. Reprocessing must be idempotent by batch/file policy, not by deleting business duplicates.
- Tables mirror source entities: `brz.Accounts`, `brz.Activities`, `brz.Campaigns`, `brz.Contacts`, `brz.Date`, `brz.Leads`, `brz.Opportunities`, `brz.OpportunityProducts`, `brz.Products`, `brz.SalesReps`, `brz.Targets`.

### Silver (`slv` schema) — validated and conformed
- Normalize types, trim strings, standardize dates and numeric precision, and apply controlled domain mappings.
- Keep rejected records and rule outcomes in `slv` exception tables; never silently drop data.
- Proposed tables: `slv.Account`, `slv.Contact`, `slv.Campaign`, `slv.Lead`, `slv.OpportunityCandidate`, `slv.OpportunityProductLine`, `slv.Activity`, `slv.Product`, `slv.SalesRep`, `slv.MonthlyTarget`, `slv.Date`, `slv.DataQualityException`, `slv.OpportunityResolution`.
- `OpportunityCandidate` retains all rows for duplicate IDs. Only one approved canonical row per business key can flow to Gold. Unresolved duplicate IDs are quarantined from trusted metrics.
- `OpportunityProductLine` gets a generated line surrogate and source lineage; `(OpportunityID, ProductID)` is not assumed unique.
- Stage controls lifecycle status; forecast category remains a separate forecast dimension. Unknown stages are excluded from trusted open pipeline until mapped.
- Target reconciliation compares monthly targets summed over a full year to `SalesReps.TargetAnnual`; discrepancies become exceptions, not automatic adjustments.

### Gold (`gld` schema) — business-ready model
- Star-schema facts and conformed dimensions for analytics.
- Dimensions: `gld.DimDate`, `gld.DimAccount`, `gld.DimContact` (if required), `gld.DimCampaign`, `gld.DimProduct`, `gld.DimSalesRep`, `gld.DimStage`, `gld.DimForecastCategory`.
- Facts: `gld.FactOpportunity` (one row per resolved opportunity), `gld.FactOpportunityProductLine` (one row per source line), `gld.FactActivity` (one row per activity), `gld.FactLead` (one row per lead), `gld.FactSalesTargetMonthly` (one row per rep-month).
- Date dimension role-playing keys: CreatedDateKey, ExpectedCloseDateKey, ActualCloseDateKey, ActivityDateKey, LeadCreatedDateKey, ConvertedDateKey and TargetMonthDateKey as appropriate.
- Trusted facts expose quality flags and source lineage for drill-through/audit.

### Governed access (`api`/`rpt` schema)
- Publish approved, read-only views such as `rpt.vw_WonRevenue`, `rpt.vw_OpenPipeline`, `rpt.vw_WeightedPipeline`, `rpt.vw_TargetAchievement`, `rpt.vw_TargetReconciliation`, and `rpt.vw_DataQualityScorecard`.
- Power BI semantic model and any future AI assistant query only approved views/semantic measures, not raw Bronze tables.
- Use least-privilege read-only access, allowlisted views, query limits, audit logs and no unrestricted arbitrary SQL execution for an AI layer.

## KPI contracts
- **Won Revenue (AED):** sum `EstimatedRevenue` for unique, resolved `Closed Won` opportunities that pass quality gates.
- **Open Pipeline (AED):** sum `EstimatedRevenue` for approved open stages only; exclude `Closed Won`, `Closed Lost`, `Unknown`, unresolved duplicate IDs and invalid records.
- **Weighted Pipeline (AED):** eligible open `EstimatedRevenue × ProbabilityPct / 100`. This is an estimate, not a commitment.
- **Win Rate:** distinct resolved Closed Won / (Closed Won + Closed Lost); date attribution and scope must be explicit.
- **Monthly Target (AED):** `Targets.RevenueTarget` by rep-month.
- **Annual Target (AED):** sum of 12 monthly revenue targets by rep-year; compare with `SalesReps.TargetAnnual`, report mismatches.
- **Target Achievement:** eligible won revenue attributed by ActualCloseDate / monthly or annual target for the same scope and period.
- **Gross Margin:** not authoritative until product line revenue and cost definitions are confirmed and reconciled.
- **Forecast accuracy / slippage:** unavailable historically from current-state records alone; start collecting dated snapshots.

## Currency contract
All Gold/reporting monetary fields are documented with `_AED` suffix where practical. The source files do not declare currency. AED is a required project reporting assumption pending confirmation that all input amounts are already AED. No FX conversion will be fabricated. Store currency metadata at ingestion if later supplied.

## Naming conventions
- SQL schemas: `brz`, `slv`, `gld`, `rpt`, `ctl` (control/operations).
- Tables: PascalCase entity names with layer-specific schema (`brz.Opportunities`, `gld.FactOpportunity`).
- Gold dimensions/facts: `Dim<Entity>`, `Fact<Process>`.
- Columns: PascalCase source-compatible names in Bronze; descriptive PascalCase in Silver/Gold. Surrogate keys end in `Key`; business identifiers end in `ID`; monetary reporting columns use `_AED`; percentages end in `Pct`; timestamps include `Utc` when UTC.
- SQL scripts: `NNN_action_object.sql`, e.g. `010_create_schemas.sql`, `020_create_control_tables.sql`.
- Python modules and tests: `snake_case.py`, `test_*.py`.
- Decisions and runbooks: Markdown under `docs/decisions` and `docs/runbooks`.

## Proposed repository layout
```text
commercial-revenue-intelligence-warehouse/
├── README.md
├── .gitignore
├── .gitattributes
├── docs/
│   ├── phase1_source_profiling_report.md
│   ├── phase2_architecture_and_repository.md
│   ├── business_requirements_and_kpi_glossary.md
│   ├── source_to_target_mapping_draft.csv
│   ├── decisions/
│   ├── runbooks/
│   └── evidence/
├── architecture/
│   ├── commercial_revenue_intelligence_architecture.drawio
│   ├── commercial_revenue_intelligence_architecture.svg
│   ├── data_flow.drawio
│   └── data_flow.svg
├── data/
│   └── sample/                 # synthetic/sanitized samples only; no sensitive exports
├── profiling/                  # generated profiling outputs
├── sql/
│   ├── 00_admin/
│   ├── 01_bronze/
│   ├── 02_silver/
│   ├── 03_gold/
│   └── 04_quality/
├── src/
│   ├── ingestion/
│   └── transforms/
└── tests/
```

## Architecture gates before Phase 3
1. Confirm source monetary currency with the source owner.
2. Obtain decisions for all 35 conflicting opportunity IDs or keep them quarantined.
3. Confirm whether repeated product pairs are legitimate separate lines and what the line grain represents.
4. Confirm `EstimatedRevenue`, `LineRevenue`, `EstimatedCost`, discount and quantity semantics.
5. Reconcile annual and monthly targets and establish target calendar conventions.
6. Approve stage-to-open/closed mapping and allowed forecast categories.
