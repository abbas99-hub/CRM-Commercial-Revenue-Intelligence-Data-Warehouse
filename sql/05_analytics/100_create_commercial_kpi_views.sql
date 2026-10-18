/* Phase 6 — governed commercial KPI views (SQL Server)
   Run after Phase 5 Gold tables have been created and populated.
   Monetary values are labelled AED per project convention; source currency still requires owner confirmation.
*/
SET NOCOUNT ON;
GO
CREATE OR ALTER VIEW rpt.vw_OpportunityKPIBase
AS
SELECT
    f.FactOpportunityKey,
    f.OpportunityID,
    f.CustomerKey,
    c.AccountID,
    c.AccountName,
    c.Industry AS CustomerIndustry,
    c.Country,
    c.Segment AS CustomerSegment,
    f.SalesRepKey,
    r.SalesRepID,
    r.SalesRepName,
    r.ManagerName,
    r.Region,
    f.CampaignKey,
    cp.CampaignID,
    cp.CampaignName,
    f.CreatedDateKey,
    dc.FullDate AS CreatedDate,
    f.ExpectedCloseDateKey,
    de.FullDate AS ExpectedCloseDate,
    f.ActualCloseDateKey,
    da.FullDate AS ActualCloseDate,
    f.Stage,
    f.ForecastCategory,
    f.Segment AS OpportunitySegment,
    f.Industry AS OpportunityIndustry,
    f.ProbabilityPct,
    f.EstimatedRevenueAED,
    f.WonRevenueAED,
    f.WeightedPipelineAED,
    f.IsTrustedForPipeline,
    CASE WHEN f.Stage IN ('Qualification','Needs Analysis','Proposal','Negotiation') THEN 1 ELSE 0 END AS IsApprovedOpenStage,
    CASE WHEN f.Stage='Closed Won' THEN 1 ELSE 0 END AS IsClosedWon,
    CASE WHEN f.Stage='Closed Lost' THEN 1 ELSE 0 END AS IsClosedLost,
    CASE WHEN f.Stage IN ('Closed Won','Closed Lost') THEN 1 ELSE 0 END AS IsClosed,
    CASE WHEN f.Stage IN ('Qualification','Needs Analysis','Proposal','Negotiation')
          AND f.IsTrustedForPipeline=1
          AND f.EstimatedRevenueAED IS NOT NULL AND f.EstimatedRevenueAED>0
          AND f.ProbabilityPct BETWEEN 0 AND 100 THEN 1 ELSE 0 END AS IsEligibleOpenPipeline,
    CASE WHEN f.Stage IN ('Closed Won','Closed Lost') AND da.FullDate IS NOT NULL THEN 1 ELSE 0 END AS IsEligibleClosedOutcome
FROM gld.FactOpportunity f
LEFT JOIN gld.DimCustomer c ON c.CustomerKey=f.CustomerKey
LEFT JOIN gld.DimSalesRep r ON r.SalesRepKey=f.SalesRepKey
LEFT JOIN gld.DimCampaign cp ON cp.CampaignKey=f.CampaignKey
LEFT JOIN gld.DimDate dc ON dc.DateKey=f.CreatedDateKey
LEFT JOIN gld.DimDate de ON de.DateKey=f.ExpectedCloseDateKey
LEFT JOIN gld.DimDate da ON da.DateKey=f.ActualCloseDateKey;
GO

/* Won revenue is attributed to actual close month, not created/expected close month. */
CREATE OR ALTER VIEW rpt.vw_WonRevenueMonthly
AS
SELECT YEAR(ActualCloseDate) AS CalendarYear, MONTH(ActualCloseDate) AS MonthNumber,
       CONVERT(char(7),ActualCloseDate,126) AS YearMonth,
       SalesRepKey, SalesRepID, SalesRepName, ManagerName, Region, CustomerKey, AccountID, AccountName,
       COUNT_BIG(*) AS WonOpportunityCount,
       SUM(EstimatedRevenueAED) AS WonRevenueAED,
       AVG(CONVERT(decimal(19,4),EstimatedRevenueAED)) AS AverageWonDealSizeAED
FROM rpt.vw_OpportunityKPIBase
WHERE IsClosedWon=1 AND ActualCloseDate IS NOT NULL AND EstimatedRevenueAED IS NOT NULL
GROUP BY YEAR(ActualCloseDate),MONTH(ActualCloseDate),CONVERT(char(7),ActualCloseDate,126),
         SalesRepKey,SalesRepID,SalesRepName,ManagerName,Region,CustomerKey,AccountID,AccountName;
GO

/* One row per eligible open opportunity. Consumers can aggregate by dimensions without mixing closed deals. */
CREATE OR ALTER VIEW rpt.vw_OpenPipeline
AS
SELECT OpportunityID, AccountID, AccountName, CustomerIndustry, Country, CustomerSegment,
       SalesRepID, SalesRepName, ManagerName, Region, CampaignID, CampaignName,
       CreatedDate, ExpectedCloseDate, Stage, ForecastCategory, ProbabilityPct,
       EstimatedRevenueAED AS OpenPipelineAED,
       DATEDIFF(day,CreatedDate,CONVERT(date,SYSUTCDATETIME())) AS OpportunityAgeDays,
       CASE WHEN ExpectedCloseDate < CONVERT(date,SYSUTCDATETIME()) THEN 1 ELSE 0 END AS IsPastExpectedCloseDate,
       CASE WHEN ExpectedCloseDate < CONVERT(date,SYSUTCDATETIME()) THEN DATEDIFF(day,ExpectedCloseDate,CONVERT(date,SYSUTCDATETIME())) ELSE 0 END AS DaysPastExpectedCloseDate
FROM rpt.vw_OpportunityKPIBase
WHERE IsEligibleOpenPipeline=1;
GO

CREATE OR ALTER VIEW rpt.vw_WeightedPipeline
AS
SELECT OpportunityID, AccountID, AccountName, CustomerSegment, SalesRepID, SalesRepName, ManagerName, Region,
       CampaignID, CampaignName, CreatedDate, ExpectedCloseDate, Stage, ForecastCategory, ProbabilityPct,
       EstimatedRevenueAED AS OpenPipelineAED,
       CONVERT(decimal(19,4),EstimatedRevenueAED * ProbabilityPct / 100.0) AS WeightedPipelineAED,
       DATEDIFF(day,CreatedDate,CONVERT(date,SYSUTCDATETIME())) AS OpportunityAgeDays
FROM rpt.vw_OpportunityKPIBase
WHERE IsEligibleOpenPipeline=1;
GO

/* Win rate is cohort of outcomes by actual close month: won / (won + lost). Unknown stages and undated outcomes excluded. */
CREATE OR ALTER VIEW rpt.vw_WinRateMonthly
AS
SELECT YEAR(ActualCloseDate) AS CalendarYear, MONTH(ActualCloseDate) AS MonthNumber,
       CONVERT(char(7),ActualCloseDate,126) AS YearMonth,
       SalesRepKey, SalesRepID, SalesRepName, ManagerName, Region,
       SUM(CASE WHEN IsClosedWon=1 THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) AS ClosedWonCount,
       SUM(CASE WHEN IsClosedLost=1 THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) AS ClosedLostCount,
       COUNT_BIG(*) AS ClosedOutcomeCount,
       CONVERT(decimal(9,4),100.0*SUM(CASE WHEN IsClosedWon=1 THEN 1.0 ELSE 0.0 END)/NULLIF(COUNT_BIG(*),0)) AS WinRatePct
FROM rpt.vw_OpportunityKPIBase
WHERE IsEligibleClosedOutcome=1
GROUP BY YEAR(ActualCloseDate),MONTH(ActualCloseDate),CONVERT(char(7),ActualCloseDate,126),
         SalesRepKey,SalesRepID,SalesRepName,ManagerName,Region;
GO

/* Target achievement aligns actual wins by ActualCloseDate month and rep. Months without wins remain visible as zero. */
CREATE OR ALTER VIEW rpt.vw_TargetAchievementMonthly
AS
WITH Won AS (
 SELECT f.SalesRepKey, YEAR(ad.FullDate) AS CalendarYear, MONTH(ad.FullDate) AS MonthNumber,
        SUM(f.EstimatedRevenueAED) AS WonRevenueAED, COUNT_BIG(*) AS WonOpportunityCount
 FROM gld.FactOpportunity f
 JOIN gld.DimDate ad ON ad.DateKey=f.ActualCloseDateKey AND ad.IsUnknown=0
 WHERE f.Stage='Closed Won' AND f.ActualCloseDateKey<>0 AND f.EstimatedRevenueAED IS NOT NULL
 GROUP BY f.SalesRepKey,YEAR(ad.FullDate),MONTH(ad.FullDate)
)
SELECT YEAR(d.FullDate) AS CalendarYear, MONTH(d.FullDate) AS MonthNumber, d.YearMonth,
       t.SalesRepKey, r.SalesRepID, r.SalesRepName, r.ManagerName, r.Region,
       t.RevenueTargetAED, COALESCE(w.WonRevenueAED,0) AS WonRevenueAED,
       COALESCE(w.WonOpportunityCount,0) AS WonOpportunityCount,
       CONVERT(decimal(19,4),100.0*COALESCE(w.WonRevenueAED,0)/NULLIF(t.RevenueTargetAED,0)) AS TargetAchievementPct,
       t.PipelineTargetAED, t.WinRateTargetPct,
       CASE WHEN t.RevenueTargetAED IS NULL THEN 'MISSING_TARGET'
            WHEN t.RevenueTargetAED=0 THEN 'ZERO_TARGET'
            ELSE 'COMPARABLE' END AS TargetStatus
FROM gld.FactSalesTarget t
JOIN gld.DimDate d ON d.DateKey=t.MonthDateKey
JOIN gld.DimSalesRep r ON r.SalesRepKey=t.SalesRepKey
LEFT JOIN Won w ON w.SalesRepKey=t.SalesRepKey AND w.CalendarYear=YEAR(d.FullDate) AND w.MonthNumber=MONTH(d.FullDate);
GO

/* Pipeline coverage uses expected-close month and monthly pipeline target; only eligible open opportunities count. */
CREATE OR ALTER VIEW rpt.vw_PipelineCoverageMonthly
AS
WITH Pipeline AS (
 SELECT f.SalesRepKey, YEAR(ed.FullDate) AS CalendarYear, MONTH(ed.FullDate) AS MonthNumber,
        SUM(f.EstimatedRevenueAED) AS OpenPipelineAED, SUM(f.WeightedPipelineAED) AS WeightedPipelineAED,
        COUNT_BIG(*) AS OpenOpportunityCount
 FROM gld.FactOpportunity f
 JOIN gld.DimDate ed ON ed.DateKey=f.ExpectedCloseDateKey AND ed.IsUnknown=0
 WHERE f.Stage IN ('Qualification','Needs Analysis','Proposal','Negotiation')
   AND f.IsTrustedForPipeline=1 AND f.EstimatedRevenueAED>0 AND f.ProbabilityPct BETWEEN 0 AND 100
   AND f.ExpectedCloseDateKey<>0
 GROUP BY f.SalesRepKey,YEAR(ed.FullDate),MONTH(ed.FullDate)
)
SELECT YEAR(d.FullDate) AS CalendarYear, MONTH(d.FullDate) AS MonthNumber, d.YearMonth,
       t.SalesRepKey, r.SalesRepID, r.SalesRepName, r.ManagerName, r.Region,
       t.PipelineTargetAED, COALESCE(p.OpenPipelineAED,0) AS OpenPipelineAED,
       COALESCE(p.WeightedPipelineAED,0) AS WeightedPipelineAED,
       COALESCE(p.OpenOpportunityCount,0) AS OpenOpportunityCount,
       CONVERT(decimal(19,4),COALESCE(p.OpenPipelineAED,0)/NULLIF(t.PipelineTargetAED,0)) AS PipelineCoverageMultiple,
       CASE WHEN t.PipelineTargetAED IS NULL THEN 'MISSING_TARGET'
            WHEN t.PipelineTargetAED=0 THEN 'ZERO_TARGET'
            ELSE 'COMPARABLE' END AS TargetStatus
FROM gld.FactSalesTarget t
JOIN gld.DimDate d ON d.DateKey=t.MonthDateKey
JOIN gld.DimSalesRep r ON r.SalesRepKey=t.SalesRepKey
LEFT JOIN Pipeline p ON p.SalesRepKey=t.SalesRepKey AND p.CalendarYear=YEAR(d.FullDate) AND p.MonthNumber=MONTH(d.FullDate);
GO

/* Activity volume is aggregated at rep/activity month, not joined to opportunities (avoids fanout). */
CREATE OR ALTER VIEW rpt.vw_SalesActivityMonthly
AS
SELECT YEAR(d.FullDate) AS CalendarYear, MONTH(d.FullDate) AS MonthNumber, d.YearMonth,
       f.SalesRepKey, r.SalesRepID, r.SalesRepName, r.ManagerName, r.Region,
       COUNT_BIG(*) AS ActivityCount,
       SUM(CONVERT(bigint,COALESCE(f.DurationMinutes,0))) AS ActivityDurationMinutes,
       COUNT(DISTINCT f.OpportunityID) AS OpportunitiesWithActivity
FROM gld.FactActivity f
JOIN gld.DimDate d ON d.DateKey=f.ActivityDateKey
JOIN gld.DimSalesRep r ON r.SalesRepKey=f.SalesRepKey
WHERE d.IsUnknown=0
GROUP BY YEAR(d.FullDate),MONTH(d.FullDate),d.YearMonth,f.SalesRepKey,r.SalesRepID,r.SalesRepName,r.ManagerName,r.Region;
GO

/* Lead conversion is by lead-created cohort, not by conversion month; there is no explicit lead-opportunity bridge. */
CREATE OR ALTER VIEW rpt.vw_LeadConversionMonthly
AS
SELECT YEAR(d.FullDate) AS CalendarYear, MONTH(d.FullDate) AS MonthNumber, d.YearMonth,
       f.SalesRepKey, r.SalesRepID, r.SalesRepName, r.ManagerName, r.Region,
       COUNT_BIG(*) AS LeadsCreated,
       SUM(CASE WHEN f.LeadStatus='Converted' THEN CONVERT(bigint,1) ELSE CONVERT(bigint,0) END) AS LeadsConverted,
       CONVERT(decimal(9,4),100.0*SUM(CASE WHEN f.LeadStatus='Converted' THEN 1.0 ELSE 0.0 END)/NULLIF(COUNT_BIG(*),0)) AS LeadConversionPct
FROM gld.FactLead f
JOIN gld.DimDate d ON d.DateKey=f.CreatedDateKey
JOIN gld.DimSalesRep r ON r.SalesRepKey=f.SalesRepKey
WHERE d.IsUnknown=0
GROUP BY YEAR(d.FullDate),MONTH(d.FullDate),d.YearMonth,f.SalesRepKey,r.SalesRepID,r.SalesRepName,r.ManagerName,r.Region;
GO

/* Provisional product-line margin: intentionally not used as authoritative won revenue. */
CREATE OR ALTER VIEW rpt.vw_ProductLineMargin
AS
SELECT p.ProductKey, pr.ProductID, pr.ProductName, pr.Category,
       COUNT_BIG(*) AS ProductLineCount,
       SUM(p.LineRevenueAED) AS ProductLineRevenueAED,
       SUM(p.EstimatedCostAED) AS EstimatedCostAED,
       SUM(p.LineRevenueAED-p.EstimatedCostAED) AS EstimatedGrossProfitAED,
       CONVERT(decimal(9,4),100.0*SUM(p.LineRevenueAED-p.EstimatedCostAED)/NULLIF(SUM(p.LineRevenueAED),0)) AS EstimatedGrossMarginPct,
       SUM(CASE WHEN p.IsOpportunityResolved=0 THEN 1 ELSE 0 END) AS LinesWithUnresolvedOpportunity
FROM gld.FactOpportunityProduct p
JOIN gld.DimProduct pr ON pr.ProductKey=p.ProductKey
GROUP BY p.ProductKey,pr.ProductID,pr.ProductName,pr.Category;
GO

/* Open opportunity ageing bands for leadership prioritization. */
CREATE OR ALTER VIEW rpt.vw_OpportunityAgeing
AS
SELECT OpportunityID,AccountID,AccountName,SalesRepID,SalesRepName,ManagerName,Region,
       Stage,ForecastCategory,EstimatedRevenueAED,ProbabilityPct,CreatedDate,ExpectedCloseDate,
       OpportunityAgeDays,IsPastExpectedCloseDate,DaysPastExpectedCloseDate,
       CASE WHEN OpportunityAgeDays IS NULL THEN 'Unknown age'
            WHEN OpportunityAgeDays<0 THEN 'Future-created / check data'
            WHEN OpportunityAgeDays<=30 THEN '0-30 days'
            WHEN OpportunityAgeDays<=60 THEN '31-60 days'
            WHEN OpportunityAgeDays<=90 THEN '61-90 days'
            ELSE '90+ days' END AS AgeingBand
FROM rpt.vw_OpenPipeline;
GO
