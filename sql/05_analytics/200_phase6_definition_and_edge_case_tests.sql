/* Phase 6 acceptance tests. Run after Gold is loaded and KPI views are created.
   Each result should be reviewed; this script intentionally reports, rather than mutates, data.
*/
SET NOCOUNT ON;

-- Test 1: Won revenue reconciles to Gold's authoritative EstimatedRevenue measure.
SELECT 'Won revenue: Gold vs KPI view' AS TestName,
       (SELECT COALESCE(SUM(WonRevenueAED),0) FROM gld.FactOpportunity WHERE Stage='Closed Won' AND ActualCloseDateKey<>0) AS GoldWonRevenueAED,
       (SELECT COALESCE(SUM(WonRevenueAED),0) FROM rpt.vw_WonRevenueMonthly) AS ViewWonRevenueAED,
       CASE WHEN ABS((SELECT COALESCE(SUM(WonRevenueAED),0) FROM gld.FactOpportunity WHERE Stage='Closed Won' AND ActualCloseDateKey<>0)-
                          (SELECT COALESCE(SUM(WonRevenueAED),0) FROM rpt.vw_WonRevenueMonthly))<0.01 THEN 'PASS' ELSE 'REVIEW' END AS Result;

-- Test 2: no unresolved/unknown stages are counted in approved open pipeline.
SELECT 'Open pipeline stage scope' AS TestName, COUNT_BIG(*) AS InvalidRows,
       CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END AS Result
FROM rpt.vw_OpenPipeline WHERE Stage NOT IN ('Qualification','Needs Analysis','Proposal','Negotiation');

-- Test 3: win-rate monthly outcomes reconcile to eligible dated closed outcomes.
SELECT 'Win-rate outcome reconciliation' AS TestName,
       (SELECT COUNT_BIG(*) FROM rpt.vw_OpportunityKPIBase WHERE Stage IN ('Closed Won','Closed Lost') AND ActualCloseDate IS NOT NULL) AS EligibleDatedOutcomes,
       (SELECT COALESCE(SUM(ClosedOutcomeCount),0) FROM rpt.vw_WinRateMonthly) AS OutcomesInView,
       CASE WHEN (SELECT COUNT_BIG(*) FROM rpt.vw_OpportunityKPIBase WHERE Stage IN ('Closed Won','Closed Lost') AND ActualCloseDate IS NOT NULL)=
                      (SELECT COALESCE(SUM(ClosedOutcomeCount),0) FROM rpt.vw_WinRateMonthly) THEN 'PASS' ELSE 'REVIEW' END AS Result;

-- Test 4: target view grain should be one row per rep and target month.
SELECT 'Target achievement grain' AS TestName, COUNT_BIG(*) AS DuplicateGroups,
       CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END AS Result
FROM (SELECT SalesRepKey,CalendarYear,MonthNumber FROM rpt.vw_TargetAchievementMonthly
      GROUP BY SalesRepKey,CalendarYear,MonthNumber HAVING COUNT_BIG(*)>1) d;

-- Test 5: ratios must remain NULL for zero or missing targets (avoid divide-by-zero / false 0%).
SELECT 'Target achievement zero-target behavior' AS TestName, COUNT_BIG(*) AS InvalidRows,
       CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END AS Result
FROM rpt.vw_TargetAchievementMonthly
WHERE (RevenueTargetAED IS NULL OR RevenueTargetAED=0) AND TargetAchievementPct IS NOT NULL;

SELECT 'Pipeline coverage zero-target behavior' AS TestName, COUNT_BIG(*) AS InvalidRows,
       CASE WHEN COUNT_BIG(*)=0 THEN 'PASS' ELSE 'FAIL' END AS Result
FROM rpt.vw_PipelineCoverageMonthly
WHERE (PipelineTargetAED IS NULL OR PipelineTargetAED=0) AND PipelineCoverageMultiple IS NOT NULL;

-- Test 6: future-created rows are reported for review, not silently clipped.
SELECT 'Future-created open opportunities' AS TestName, COUNT_BIG(*) AS ReviewRows
FROM rpt.vw_OpportunityAgeing WHERE AgeingBand='Future-created / check data';

-- Test 7: unknown dimension assignments and untrusted pipeline rows must be visible to owners.
SELECT 'Unknown dimension mappings' AS Metric, COUNT_BIG(*) AS RowCount FROM gld.FactOpportunity WHERE CustomerKey=0 OR SalesRepKey=0 OR CampaignKey=0
UNION ALL SELECT 'Untrusted opportunity rows',COUNT_BIG(*) FROM gld.FactOpportunity WHERE IsTrustedForPipeline=0
UNION ALL SELECT 'Unresolved product lines',COUNT_BIG(*) FROM gld.FactOpportunityProduct WHERE IsOpportunityResolved=0;

-- Test 8: monthly activity and lead views should be unique at rep-month grain.
SELECT 'Activity monthly grain' AS TestName, COUNT_BIG(*) AS DuplicateGroups
FROM (SELECT SalesRepKey,YearMonth FROM rpt.vw_SalesActivityMonthly GROUP BY SalesRepKey,YearMonth HAVING COUNT_BIG(*)>1) d;
SELECT 'Lead conversion monthly grain' AS TestName, COUNT_BIG(*) AS DuplicateGroups
FROM (SELECT SalesRepKey,YearMonth FROM rpt.vw_LeadConversionMonthly GROUP BY SalesRepKey,YearMonth HAVING COUNT_BIG(*)>1) d;

-- Test 9: product-line revenue and won estimated revenue are intentionally compared, not assumed equal.
SELECT 'Product-line revenue vs won revenue (not expected equal)' AS Comparison,
       (SELECT COALESCE(SUM(LineRevenueAED),0) FROM gld.FactOpportunityProduct WHERE IsOpportunityResolved=1) AS ResolvedLineRevenueAED,
       (SELECT COALESCE(SUM(WonRevenueAED),0) FROM gld.FactOpportunity) AS WonEstimatedRevenueAED;
GO
