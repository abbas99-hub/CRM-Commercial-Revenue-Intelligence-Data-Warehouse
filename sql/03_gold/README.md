# Gold layer

1. `100_create_gold_tables.sql` — dimension/fact DDL and FK constraints.
2. `110_load_gold.sql` — transactional full refresh procedure `gld.usp_LoadGold`.
3. `200_gold_relationship_and_aggregation_checks.sql` — grain, FK, row count and revenue reconciliation checks.

Run only after the Phase 4 Silver transforms have succeeded. This implementation is a portfolio/full-refresh design, not an incremental SCD pipeline.
