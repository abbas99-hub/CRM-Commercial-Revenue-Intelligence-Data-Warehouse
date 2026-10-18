# Phase 4 completion gate

## Current status

The eight remaining typed Silver entities and their transformation logic have now been authored. Offline validation against the supplied CSV files passed: 11 expected files, 93,837 rows, matching headers, zero malformed row widths, 35 duplicate opportunity IDs (70 rows in conflicting groups), 203 repeated opportunity/product pairs (406 rows involved), and no duplicate target month/rep grains.

**Phase 4 is not operationally certified yet** because the SQL scripts have not been executed against a live SQL Server. The environment used to prepare the project has no SQL Server instance/client available.

## Required live acceptance steps

1. Load all 11 CSVs into Bronze and confirm counts match `profiling/phase4_source_count_baseline.csv`.
2. Run `100_create_silver_tables.sql`, `120_create_remaining_silver_tables.sql`, `110_transform_opportunities_and_targets.sql`, and `130_transform_remaining_entities.sql` in that order.
3. Execute both transform procedures.
4. Run `200_silver_quality_checks.sql` and `210_phase4_full_reconciliation.sql`; export result sets under `docs/evidence/phase4/`.
5. Execute both procedures a second time and confirm stable row counts and no uncontrolled duplicate exception accumulation.
6. Test schema drift by changing a copied test CSV header and confirm the Bronze loader rejects/logs it before loading; do not alter the source baseline files.
7. Confirm 35 duplicate OpportunityID groups (70 rows) are quarantined, unless source data has changed. No arbitrary record is selected.
8. Confirm target reconciliation: 2024 and 2025 monthly sums are within AED 0.05 rounding tolerance; 2026 is partial through September and not comparable to a full-year target.
9. Review referential-integrity findings and explain every Bronze/Silver row difference.
10. Confirm the source-currency assumption with the owner before representing AED as verified original currency.

No live SQL execution or database row-count results are claimed in this package.
