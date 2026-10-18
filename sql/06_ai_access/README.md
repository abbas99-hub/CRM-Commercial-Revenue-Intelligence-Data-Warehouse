# Phase 7 — AI-ready access layer

Execution order:
1. `100_create_ai_business_views.sql` (requires Phase 6 views)
2. `110_ai_access_permissions.sql` (adapt principal and security policy)
3. `200_ai_access_smoke_tests.sql`

Prototype: `src/ai_access/governed_query_demo.py`. It supports only named intents with parameterized SQL and is explain-only unless `WAREHOUSE_SQL_CONNECTION` is set. Do not grant the AI identity direct access to Bronze, Silver, or Gold tables.
