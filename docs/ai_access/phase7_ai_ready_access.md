# Phase 7 — AI-ready access layer

## Objective
Expose the approved Phase 6 KPI layer through stable, business-named `rpt.ai_*` views and provide a constrained query prototype. The AI identity should not query `brz`, `slv`, or `gld` directly.

## Approved view catalogue

| View | Grain | Business use | Main measures / caveats |
|---|---|---|---|
| `rpt.ai_WonRevenueByMonth` | Month × rep × customer | Actual sales performance | Won revenue uses `EstimatedRevenueAED`, grouped by actual close month. |
| `rpt.ai_OpenPipeline` | One eligible open opportunity | Pipeline review and overdue follow-up | Excludes unknown stage, unresolved/untrusted records, invalid/non-positive revenue and invalid probability. Age is current, not historical. |
| `rpt.ai_WeightedPipeline` | One eligible open opportunity | Probability-weighted pipeline | Estimated revenue × probability / 100; not a guaranteed forecast. |
| `rpt.ai_WinRateByMonth` | Month × rep | Sales effectiveness | Won / (won + lost), grouped by actual close month; only dated closed outcomes count. |
| `rpt.ai_TargetAchievementByMonth` | Month × rep target row | Target attainment | Actuals assigned by actual close month. Zero/missing target yields NULL percentage and a status. |
| `rpt.ai_OpportunityAgeing` | One eligible open opportunity | Deal ageing and overdue management | Current age and overdue days; based on current UTC date. |
| `rpt.ai_LeadConversionByMonth` | Lead-created month × rep | Lead cohort conversion | Converted / created leads in the cohort; not conversion-month reporting. No lead-opportunity bridge exists. |
| `rpt.ai_SalesActivityByMonth` | Activity month × rep | Activity workload and coverage | Activity counts and duration; activity volume does not prove causation or effectiveness. |
| `rpt.ai_ProductLineMargin` | Product | Provisional product margin | Uses line revenue and estimated cost; not authoritative won revenue, and source semantics need confirmation. |

## Natural-language question catalogue

The prototype supports a fixed set of intents. It does **not** turn unrestricted natural language into SQL. An upstream assistant can classify a user's request into one of these intents, extract validated filters, and call the approved query adapter. The user should be told which metric, time basis and filters were used.

| Example question | Approved intent | Expected output columns / shape | Important interpretation |
|---|---|---|---|
| “Show won revenue by representative for September 2026.” | `won_revenue` with month `2026-09` | Month, representative, manager, region, won deals, won revenue AED, average won deal AED | Actual close month; values only after trusted Gold data is loaded. |
| “Which open opportunities are overdue in the North region?” | `open_pipeline` with region `North` | Opportunity ID, customer, rep, stage, expected close, pipeline AED, age, overdue flag/days | Eligible open stages only; expected-close date must be present for date filters, current-age logic. |
| “What is the weighted pipeline by opportunity?” | `weighted_pipeline` | Opportunity ID, customer, rep, expected close, pipeline AED, probability, weighted pipeline AED | Uses the stored probability as a simple weight, not a calibrated forecast model. |
| “Compare win rates by rep in September 2026.” | `win_rate` with month `2026-09` | Won deals, lost deals, closed deals, win rate percent by rep | Actual close-month cohort; undated outcomes excluded. |
| “Who achieved at least 100% of monthly revenue target in September?” | `target_achievement` with month `2026-09` | Revenue target AED, won revenue AED, achievement percent, target status | Apply threshold `TargetAchievementPct >= 100` only when status is `COMPARABLE`; this threshold can be applied to returned rows or added as a fixed approved filter. |
| “Which opportunities have been open for over 90 days?” | `ageing` | Opportunity ID, customer, rep, age in days, ageing band, overdue days | Current snapshot; do not describe this as historical ageing. |
| “How did lead conversion perform by created month?” | `lead_conversion` | Leads created, leads converted, conversion percent by cohort | Conversion is by created month, not conversion month. |

## Expected SQL/result contract

Example query for won revenue (equivalent approved SQL):

```sql
SELECT [Year], [Month], SalesRepresentative, Manager, Region,
       WonDeals, WonRevenueAED, AverageWonDealAED
FROM rpt.ai_WonRevenueByMonth
WHERE [Month] = @Month
ORDER BY WonRevenueAED DESC;
```

Expected result: zero or more rows, one per month × representative × customer in this view. No fixed numeric output is documented until the Gold model has been populated and the SQL tests have run. An empty result means no matching records in the approved view, not zero revenue by itself.

Example query for overdue opportunities:

```sql
SELECT OpportunityID, Customer, SalesRepresentative, Stage,
       ExpectedCloseDate, OpenPipelineAED, AgeInDays, DaysPastDue
FROM rpt.ai_OpenPipeline
WHERE Region = @Region AND IsPastExpectedCloseDate = 1
ORDER BY DaysPastDue DESC, OpenPipelineAED DESC;
```

Expected result: one row per matching eligible opportunity. Never join this result directly to activity or product-line rows and then sum pipeline value; that would multiply opportunity amounts.

## Governance and security

1. Run `sql/06_ai_access/100_create_ai_business_views.sql` after Phase 6 views have been installed and validated.
2. Review and adapt `sql/06_ai_access/110_ai_access_permissions.sql` for your database principal. Grant only `SELECT` on approved `rpt.ai_*` views; do not grant broad `db_datareader` or direct base-table access.
3. Use a read-only SQL identity, least privilege, connection timeout, query timeout, result-row cap, and audit logs in a deployed service.
4. The included Python adapter uses a fixed allowlist of parameterized SQL templates. It does not accept a raw SQL argument, does not call an LLM, and cannot generate a new query shape at runtime.
5. Validate identity-based row-level security before exposing customer or rep details to broader users. Current SQL grants are database-role-level only; they do not implement row-level security by themselves.
6. Treat source currency as unverified. Monetary names are AED by project convention until a data owner confirms the original source currency.
7. Never present product-line margin as the authoritative won revenue measure. Never claim forecast accuracy or close-date slippage without historical snapshots.

## Prototype execution

List available intents:

```bash
python src/ai_access/governed_query_demo.py --list
```

Show an explain-only plan (no database connection):

```bash
python src/ai_access/governed_query_demo.py --intent open_pipeline --region North --limit 20
```

Execute against a configured SQL Server:

```powershell
$env:WAREHOUSE_SQL_CONNECTION = "<read-only ODBC connection string>"
python src/ai_access/governed_query_demo.py --intent target_achievement --month 2026-09
```

Install `pyodbc` and the SQL Server ODBC driver as required. The prototype reports `EXPLAIN ONLY` if no connection is configured. It must run under the restricted AI-reader principal, not a database owner account.

## Validation and acceptance criteria

- The nine business views compile and return metadata under the restricted principal.
- AI role can select approved views but cannot select `gld.FactOpportunity`, `slv.*`, or `brz.*` directly.
- Every query intent uses a fixed view and parameterized filters; raw SQL input is not supported.
- `--limit` is constrained to 1–500 and date/month formats are validated.
- View result grains are checked by `200_ai_access_smoke_tests.sql` where uniqueness is expected.
- KPI reconciliation is still governed by Phase 6 tests; this package does not substitute for runtime execution.
- A real LLM-to-intent classifier is not included because no model/API environment was provided. This is a governed data-access prototype, not a production conversational agent.
