# Phase 6 — Commercial SQL Analytics

Run `100_create_commercial_kpi_views.sql` after Gold tables are populated. Then run `200_phase6_definition_and_edge_case_tests.sql` and review results. See `docs/phase6_kpi_glossary_and_management_queries.md` for definitions and example management questions.

Views are read-only semantic/reporting views. They do not modify facts. They implement `EstimatedRevenueAED` as authoritative won revenue, approved open-stage filters, actual-close-month win rate, target matching by rep/month, current-state ageing, lead-created cohort conversion, and provisional product-line margin.

Runtime SQL Server validation has not been performed in the build environment.
