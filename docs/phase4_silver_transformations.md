# Phase 4 — Silver transformations and quarantine

## SQL execution order

1. Execute Phase 3 schema/control/Bronze DDL and load all 11 CSV files.
2. Execute `sql/02_silver/100_create_silver_tables.sql`.
3. Execute `sql/02_silver/120_create_remaining_silver_tables.sql`.
4. Execute `sql/02_silver/110_transform_opportunities_and_targets.sql` to create `slv.usp_TransformOpportunitiesAndTargets`.
5. Execute `sql/02_silver/130_transform_remaining_entities.sql` to create `slv.usp_TransformRemainingEntities`.
6. Run `EXEC slv.usp_TransformOpportunitiesAndTargets;`.
7. Run `EXEC slv.usp_TransformRemainingEntities;`.
8. Execute `sql/04_quality/200_silver_quality_checks.sql` and `sql/04_quality/210_phase4_full_reconciliation.sql` and save result sets as evidence.

Both procedures rebuild their managed Silver tables transactionally from Bronze. Re-running should yield stable Silver counts for unchanged Bronze data. Bronze remains the immutable source of record.

## Entity transformations

- Accounts: unique AccountID; non-negative revenue and employee counts; monetary field labelled AED as a project assumption.
- Activities: unique ActivityID; typed ActivityDate and non-negative duration.
- Campaigns: unique CampaignID; typed start date and non-negative budget.
- Contacts: unique ContactID; normalize EmailOptIn into nullable bit.
- Date: one row per date; derive canonical year/month/quarter attributes from the date and validate supplied year/month/year-month attributes. Surrogate date key is `YYYYMMDD`.
- Leads: unique LeadID; canonical statuses Open, Converted, Nurture and Disqualified; Converted leads require ConvertedDate, non-converted leads must not have one.
- OpportunityProducts: one Silver row per valid source row; preserve repeated OpportunityID/ProductID pairs because they may be legitimate line items. Each row retains BronzeRowID lineage.
- Products: unique ProductID; non-negative unit price; margin constrained to 0–100; normalize Active into nullable bit.
- Opportunities: duplicate OpportunityID groups are quarantined in full; invalid typed fields are excluded; unknown stages and stage/forecast category mismatches are logged.
- SalesReps: unique SalesRepID; annual target non-negative.
- Targets: one row per Month/SalesRepID; duplicate grains are quarantined in full; win-rate target normalized to a proportion in Silver (0–1).

## Duplicate and exception policy

No arbitrary row selection is used for duplicate business keys. All rows in a duplicate key group are excluded from trusted Silver business-key tables until an authoritative resolution is documented. Product-line pairs are not treated as unique. Exception rows include rule code, entity, business key, Bronze row ID, batch, severity and timestamp.

## Source-to-Silver count reconciliation

`sql/04_quality/210_phase4_full_reconciliation.sql` reports Bronze count, Silver count and rows not present in Silver per entity, plus exception counts and referential-integrity findings. Differences must be explained by explicit validation/quarantine rules. The procedure does not assume that Silver row counts must equal Bronze when invalid or conflicting rows are excluded.


## Target reconciliation

Annual targets on SalesReps and monthly targets on Targets are compared by rep/year. Full-year monthly sums differ from annual targets by up to AED 0.04 in the supplied dataset, consistent with monthly target rounding. A tolerance of AED 0.05 is therefore used: <= AED 0.005 is `MATCH`; > AED 0.005 and <= AED 0.05 is `MATCH_WITH_ROUNDING_TOLERANCE`; larger differences are `MISMATCH_REVIEW`. Do not overwrite either source value. 2026 is partial through September and remains `PARTIAL_YEAR_NOT_COMPARABLE`.

Offline source reconciliation baseline: 2024: 50 reps within rounding tolerance; 2025: 50 reps within rounding tolerance; 2026: 50 reps partial-year/not comparable. This is a source-file calculation, not yet a live SQL reconciliation result.
