# Phase 8 — Validation evidence and test matrix

**Evidence generated:** 17 October 2026. **Scope:** offline source validation and local Python checks. SQL Server runtime execution was not available and is explicitly marked pending.

## Results

| Test / check | Expected | Observed | Status | Evidence / command |
|---|---|---|---|---|
| Core source entities | 11 entities | 11 CSV entities validated | PASS | `python src/validation/validate_phase4_sources.py --source-dir data/sample --out docs/evidence/phase8_offline_source_validation.json` |
| Total source rows | 93,837 | 93,837 | PASS | JSON report `checks.total_source_row_count` |
| Malformed CSV row widths | 0 | 0 across all 11 core entities | PASS | Per-file `malformed_row_width_count` |
| Duplicate opportunity IDs | 35 duplicate ID groups expected | 35 groups; 70 rows in groups | PASS / exception detected | JSON report; all 70 rows excluded from source-level opportunity KPIs |
| Repeated opportunity-product pairs | 203 pairs / 406 rows expected | 203 pairs / 406 rows | PASS / exception preserved | JSON report |
| Target grain | No duplicate Month + SalesRepID | 0 duplicate grains | PASS | JSON report |
| Python unit tests | All contract tests pass | **6 tests passed** | PASS | [`python_unit_tests.txt`](python_unit_tests.txt); `python -m unittest discover -s tests -v` |
| Python syntax compilation | All authored Python scripts compile | Exit code 0 | PASS | [`python_syntax_check.txt`](python_syntax_check.txt) |
| Governed query prototype, no connection | Explain-only, no DB execution | Explain-only output captured; no query executed | PASS for no-connection smoke test | [`ai_query_explain_only.txt`](ai_query_explain_only.txt) |
| SQL DDL and procedures | All scripts compile/execute in SQL Server | Not executed in this environment | PENDING | Execute scripts in README order and retain actual outputs |
| KPI view reconciliation | SQL results agree with source-level baseline after documented exclusions | Not executed | PENDING | Run Phase 4/5/6 tests and compare to KPI snapshot |
| Restricted AI role | Approved views readable; raw/base tables denied | Not executed | PENDING | Run under dedicated SQL principal, not owner/admin |
| LLM integration | Approved intent extraction works end-to-end | Not implemented | OUT OF SCOPE | Fixed-intent parameterized SQL adapter only |

## Reproduction commands

```bash
python src/validation/validate_phase4_sources.py --source-dir data/sample --out docs/evidence/phase8_offline_source_validation.json
python src/analysis/build_business_answers.py --data-dir data/sample --out-dir docs/evidence --as-of 2026-10-17
python -m unittest discover -s tests -v
python -m py_compile src/ingestion/load_bronze.py src/validation/validate_phase4_sources.py src/ai_access/governed_query_demo.py src/analysis/build_business_answers.py
python src/ai_access/governed_query_demo.py --intent open_pipeline --region North --limit 20
```

## What PASS means—and does not mean

- Offline PASS means the supplied files match the documented source contract and the Python checks completed locally.
- The anomaly checks identify exceptions; they do not mean every source row is business-valid.
- The source-level KPI snapshot is an independent descriptive baseline, not a SQL Server query result.
- No SQL Server stored procedure, Gold load, reporting view, SQL permission denial, or external LLM interaction is claimed as tested until executed and evidenced in a real environment.
