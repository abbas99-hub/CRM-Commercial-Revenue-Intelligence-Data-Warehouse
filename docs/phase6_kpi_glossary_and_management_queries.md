# Phase 6 — Commercial SQL Analytics: KPI Glossary and Management Queries

## Purpose and usage

The `rpt` schema contains reusable SQL views for commercial leadership, Power BI and a future governed AI interface. The views expose a consistent KPI layer and avoid repeating slightly different metric definitions in every dashboard.

## KPI glossary

| KPI | Definition | Time attribution | Exclusions / caveats |
|---|---|---|---|
| Won revenue (AED) | Sum `EstimatedRevenueAED` for unique `Closed Won` opportunities | Actual close date month | Undated wins are excluded from monthly trend but remain visible in base fact reconciliation; unresolved duplicate IDs must not enter Gold |
| Won opportunities | Count of eligible `Closed Won` opportunity records | Actual close date month | One row per resolved opportunity |
| Average won deal size | Won revenue divided by won opportunity count; equivalent to average estimated revenue for eligible wins | Actual close date month | Does not use product-line revenue |
| Open pipeline (AED) | Sum estimated revenue for approved open stages `Qualification`, `Needs Analysis`, `Proposal`, `Negotiation` where trusted and positive revenue and valid probability exist | Open pipeline view is current-state; monthly coverage uses expected close month | Excludes Closed Won, Closed Lost, Unknown, untrusted or invalid rows |
| Weighted pipeline (AED) | Sum `EstimatedRevenueAED × ProbabilityPct / 100` for eligible open opportunities | Current-state; expected-close month for coverage view | Probability-weighted estimate, not guaranteed forecast |
| Win rate (%) | Closed Won / (Closed Won + Closed Lost) × 100 | Actual close month | Undated outcomes excluded; unknown stages excluded; do not average row-level percentages—recalculate from counts when aggregating |
| Target achievement (%) | Won revenue / monthly revenue target × 100 | Actual close month and sales rep | Null for zero/missing target; months without wins show zero actuals; actuals are matched to target month and rep |
| Pipeline coverage (x) | Eligible open pipeline with expected close in month / pipeline target for that rep-month | Expected close month | Null for zero/missing target; interpret with stage mix and timing |
| Opportunity age (days) | Current UTC date minus CreatedDate for eligible open opportunities | Current snapshot | Dynamic, not a historical age series; future-created rows flagged for review |
| Days past expected close | Current UTC date minus ExpectedCloseDate if date is in the past | Current snapshot | Applies to eligible open opportunities; does not prove close-date slippage without snapshots |
| Lead conversion (%) | Converted leads / leads created in cohort × 100 | Lead-created month | Status-based conversion; no explicit lead-to-opportunity bridge, so this is not a revenue conversion rate |
| Activity volume | Count of activity records; duration is summed separately | Activity date month | Descriptive engagement indicator, not evidence of causal impact |
| Estimated product-line gross margin (%) | (LineRevenue − EstimatedCost) / LineRevenue × 100 | Current product-line dataset | Provisional; only resolved opportunity lines should be interpreted carefully; not the authoritative won-revenue metric |

## View catalogue

- `rpt.vw_OpportunityKPIBase` — one row per Gold opportunity with dimensions, dates and stage flags.
- `rpt.vw_WonRevenueMonthly` — won revenue and deal counts by actual close month, rep and customer.
- `rpt.vw_OpenPipeline` — opportunity-level current open pipeline and ageing fields.
- `rpt.vw_WeightedPipeline` — opportunity-level weighted pipeline.
- `rpt.vw_WinRateMonthly` — closed outcomes and win rate by actual close month and rep.
- `rpt.vw_TargetAchievementMonthly` — monthly rep target and won-revenue achievement.
- `rpt.vw_PipelineCoverageMonthly` — open pipeline compared with pipeline target by expected-close month and rep.
- `rpt.vw_SalesActivityMonthly` — activity count, duration and opportunities with activity by rep-month.
- `rpt.vw_LeadConversionMonthly` — lead-created cohort conversion by rep-month.
- `rpt.vw_ProductLineMargin` — provisional product line revenue/cost/margin.
- `rpt.vw_OpportunityAgeing` — open opportunity ageing bands.

## Management queries

### 1. Monthly won revenue and target achievement

```sql
SELECT CalendarYear, MonthNumber, SalesRepName, Region,
       WonRevenueAED, RevenueTargetAED, TargetAchievementPct
FROM rpt.vw_TargetAchievementMonthly
WHERE CalendarYear = 2026
ORDER BY MonthNumber, WonRevenueAED DESC;
```

### 2. Top open pipeline opportunities requiring attention

```sql
SELECT TOP (25) OpportunityID, AccountName, SalesRepName, Stage,
       ForecastCategory, OpenPipelineAED, ProbabilityPct,
       ExpectedCloseDate, OpportunityAgeDays, DaysPastExpectedCloseDate
FROM rpt.vw_OpenPipeline
ORDER BY IsPastExpectedCloseDate DESC, OpenPipelineAED DESC;
```

### 3. Pipeline coverage by manager and month

```sql
SELECT CalendarYear, MonthNumber, ManagerName,
       SUM(OpenPipelineAED) AS OpenPipelineAED,
       SUM(PipelineTargetAED) AS PipelineTargetAED,
       SUM(OpenPipelineAED) / NULLIF(SUM(PipelineTargetAED),0) AS CoverageMultiple
FROM rpt.vw_PipelineCoverageMonthly
WHERE CalendarYear = 2026
GROUP BY CalendarYear, MonthNumber, ManagerName
ORDER BY MonthNumber, ManagerName;
```

### 4. Win rate with correct aggregation

```sql
SELECT CalendarYear, MonthNumber, Region,
       SUM(ClosedWonCount) AS WonCount,
       SUM(ClosedLostCount) AS LostCount,
       100.0 * SUM(ClosedWonCount) /
         NULLIF(SUM(ClosedWonCount) + SUM(ClosedLostCount),0) AS WinRatePct
FROM rpt.vw_WinRateMonthly
GROUP BY CalendarYear, MonthNumber, Region
ORDER BY CalendarYear, MonthNumber, Region;
```

### 5. Ageing and overdue pipeline by owner

```sql
SELECT SalesRepName, AgeingBand, COUNT_BIG(*) AS OpportunityCount,
       SUM(OpenPipelineAED) AS OpenPipelineAED,
       SUM(CASE WHEN IsPastExpectedCloseDate=1 THEN 1 ELSE 0 END) AS PastDueCount
FROM rpt.vw_OpportunityAgeing
GROUP BY SalesRepName, AgeingBand
ORDER BY SalesRepName, AgeingBand;
```

### 6. Lead conversion by created cohort

```sql
SELECT YearMonth, Region, SUM(LeadsCreated) AS LeadsCreated,
       SUM(LeadsConverted) AS LeadsConverted,
       100.0*SUM(LeadsConverted)/NULLIF(SUM(LeadsCreated),0) AS LeadConversionPct
FROM rpt.vw_LeadConversionMonthly
GROUP BY YearMonth, Region
ORDER BY YearMonth, Region;
```

### 7. Sales activity and pipeline side by side (aggregate separately first)

```sql
WITH A AS (
 SELECT YearMonth, SalesRepKey, SUM(ActivityCount) AS ActivityCount,
        SUM(ActivityDurationMinutes) AS ActivityMinutes
 FROM rpt.vw_SalesActivityMonthly GROUP BY YearMonth, SalesRepKey
), P AS (
 SELECT CONVERT(char(7),ExpectedCloseDate,126) AS YearMonth,
        SalesRepKey, SUM(OpenPipelineAED) AS OpenPipelineAED
 FROM rpt.vw_OpenPipeline GROUP BY CONVERT(char(7),ExpectedCloseDate,126), SalesRepKey
)
SELECT COALESCE(A.YearMonth,P.YearMonth) AS YearMonth,
       COALESCE(A.SalesRepKey,P.SalesRepKey) AS SalesRepKey,
       A.ActivityCount,A.ActivityMinutes,P.OpenPipelineAED
FROM A FULL JOIN P ON P.YearMonth=A.YearMonth AND P.SalesRepKey=A.SalesRepKey;
```

## Edge cases and interpretation rules

1. **Zero/missing target:** achievement and coverage ratios are `NULL`, not 0% or infinity; inspect `TargetStatus`.
2. **No wins in a month:** target achievement displays zero won revenue if a target row exists.
3. **Undated won/lost record:** excluded from monthly win rate and monthly won revenue because no defensible month attribution exists.
4. **Unknown/unrecognized stage:** excluded from trusted pipeline and win-rate denominator.
5. **Bad probability or nonpositive revenue:** excluded from open pipeline; fix upstream or document the exception.
6. **Current age:** computed against `SYSUTCDATETIME()` and is dynamic. Do not compare snapshots unless snapshot history is implemented.
7. **Duplicate opportunities:** all conflicting rows must remain excluded until an authoritative canonical record is approved.
8. **Opportunity-product line repeats:** valid separate lines may exist; do not deduplicate by `(OpportunityID, ProductID)`.
9. **Revenue reconciliation:** product `LineRevenueAED` is a separate measure; it is not expected to equal won `EstimatedRevenueAED` until business semantics are validated.
10. **Fanout:** never directly join opportunity, activity and product-line facts and then sum their measures. Aggregate each fact to a common grain first.
11. **Historical forecast accuracy:** cannot be reconstructed from current-state opportunity rows alone; future snapshots/change history are required.
12. **AED assumption:** confirm source currency before presenting the amounts as verified AED in a real business context.

## Execution and test sequence

1. Ensure schemas and Gold tables exist and `gld.usp_LoadGold` completed successfully.
2. Run `sql/05_analytics/100_create_commercial_kpi_views.sql`.
3. Run `sql/05_analytics/200_phase6_definition_and_edge_case_tests.sql`.
4. Review each test result, especially revenue reconciliation, target grain, unknown mappings and untrusted rows.
5. Capture the SQL Server version, execution date, row counts and results as project evidence. Offline code review is not a substitute for runtime validation.
