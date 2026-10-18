/* Phase 7 smoke tests: expected to return metadata/counts, not fabricated KPI values. */
SET NOCOUNT ON;
SELECT 'ai_WonRevenueByMonth' AS ViewName, COUNT_BIG(*) AS RowCount FROM rpt.ai_WonRevenueByMonth
UNION ALL SELECT 'ai_OpenPipeline', COUNT_BIG(*) FROM rpt.ai_OpenPipeline
UNION ALL SELECT 'ai_WeightedPipeline', COUNT_BIG(*) FROM rpt.ai_WeightedPipeline
UNION ALL SELECT 'ai_WinRateByMonth', COUNT_BIG(*) FROM rpt.ai_WinRateByMonth
UNION ALL SELECT 'ai_TargetAchievementByMonth', COUNT_BIG(*) FROM rpt.ai_TargetAchievementByMonth
UNION ALL SELECT 'ai_OpportunityAgeing', COUNT_BIG(*) FROM rpt.ai_OpportunityAgeing
UNION ALL SELECT 'ai_LeadConversionByMonth', COUNT_BIG(*) FROM rpt.ai_LeadConversionByMonth
UNION ALL SELECT 'ai_SalesActivityByMonth', COUNT_BIG(*) FROM rpt.ai_SalesActivityByMonth
UNION ALL SELECT 'ai_ProductLineMargin', COUNT_BIG(*) FROM rpt.ai_ProductLineMargin;
GO
/* Duplicate-grain checks for aggregate views. Expect zero rows from each query. */
SELECT [Year],[Month],SalesRepID,CustomerID,COUNT_BIG(*) AS DuplicateRows
FROM rpt.ai_WonRevenueByMonth GROUP BY [Year],[Month],SalesRepID,CustomerID HAVING COUNT_BIG(*)>1;
SELECT [Year],[Month],SalesRepID,COUNT_BIG(*) AS DuplicateRows
FROM rpt.ai_WinRateByMonth GROUP BY [Year],[Month],SalesRepID HAVING COUNT_BIG(*)>1;
SELECT [Year],[Month],SalesRepID,COUNT_BIG(*) AS DuplicateRows
FROM rpt.ai_TargetAchievementByMonth GROUP BY [Year],[Month],SalesRepID HAVING COUNT_BIG(*)>1;
GO
