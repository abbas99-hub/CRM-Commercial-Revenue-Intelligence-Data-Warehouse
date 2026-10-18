/* Phase 7: stable, business-named, allowlisted views for AI/query consumers.
   These views do not grant permissions by themselves. Apply least-privilege role grants separately.
   Run after Phase 6 analytics views exist and have been validated.
*/
SET NOCOUNT ON;
GO
CREATE OR ALTER VIEW rpt.ai_WonRevenueByMonth
AS
SELECT CalendarYear AS [Year], MonthNumber AS [MonthNumber], YearMonth AS [Month],
       SalesRepID AS [SalesRepID], SalesRepName AS [SalesRepresentative],
       ManagerName AS [Manager], Region AS [Region], AccountID AS [CustomerID],
       AccountName AS [Customer], WonOpportunityCount AS [WonDeals],
       WonRevenueAED AS [WonRevenueAED], AverageWonDealSizeAED AS [AverageWonDealAED]
FROM rpt.vw_WonRevenueMonthly;
GO
CREATE OR ALTER VIEW rpt.ai_OpenPipeline
AS
SELECT OpportunityID AS [OpportunityID], AccountID AS [CustomerID], AccountName AS [Customer],
       SalesRepID AS [SalesRepID], SalesRepName AS [SalesRepresentative], ManagerName AS [Manager],
       Region AS [Region], Stage AS [Stage], ForecastCategory AS [ForecastCategory],
       ExpectedCloseDate AS [ExpectedCloseDate], OpenPipelineAED AS [OpenPipelineAED],
       ProbabilityPct AS [ProbabilityPct], OpportunityAgeDays AS [AgeInDays],
       IsPastExpectedCloseDate AS [IsPastExpectedCloseDate], DaysPastExpectedCloseDate AS [DaysPastDue]
FROM rpt.vw_OpenPipeline;
GO
CREATE OR ALTER VIEW rpt.ai_WeightedPipeline
AS
SELECT OpportunityID AS [OpportunityID], AccountID AS [CustomerID], AccountName AS [Customer],
       SalesRepID AS [SalesRepID], SalesRepName AS [SalesRepresentative], ManagerName AS [Manager],
       Region AS [Region], ExpectedCloseDate AS [ExpectedCloseDate], Stage AS [Stage],
       ForecastCategory AS [ForecastCategory], ProbabilityPct AS [ProbabilityPct],
       OpenPipelineAED AS [OpenPipelineAED], WeightedPipelineAED AS [WeightedPipelineAED],
       OpportunityAgeDays AS [AgeInDays]
FROM rpt.vw_WeightedPipeline;
GO
CREATE OR ALTER VIEW rpt.ai_WinRateByMonth
AS
SELECT CalendarYear AS [Year], MonthNumber AS [MonthNumber], YearMonth AS [Month],
       SalesRepID AS [SalesRepID], SalesRepName AS [SalesRepresentative],
       ManagerName AS [Manager], Region AS [Region], ClosedWonCount AS [WonDeals],
       ClosedLostCount AS [LostDeals], ClosedOutcomeCount AS [ClosedDeals], WinRatePct AS [WinRatePct]
FROM rpt.vw_WinRateMonthly;
GO
CREATE OR ALTER VIEW rpt.ai_TargetAchievementByMonth
AS
SELECT CalendarYear AS [Year], MonthNumber AS [MonthNumber], YearMonth AS [Month],
       SalesRepID AS [SalesRepID], SalesRepName AS [SalesRepresentative], ManagerName AS [Manager],
       Region AS [Region], RevenueTargetAED AS [RevenueTargetAED], WonRevenueAED AS [WonRevenueAED],
       TargetAchievementPct AS [TargetAchievementPct], PipelineTargetAED AS [PipelineTargetAED],
       TargetStatus AS [TargetStatus]
FROM rpt.vw_TargetAchievementMonthly;
GO
CREATE OR ALTER VIEW rpt.ai_OpportunityAgeing
AS
SELECT OpportunityID AS [OpportunityID], CustomerID=AccountID, Customer=AccountName,
       SalesRepID AS [SalesRepID], SalesRepresentative=SalesRepName, Manager=ManagerName,
       Region AS [Region], Stage AS [Stage], ForecastCategory AS [ForecastCategory],
       EstimatedRevenueAED AS [EstimatedRevenueAED], ProbabilityPct AS [ProbabilityPct],
       CreatedDate AS [CreatedDate], ExpectedCloseDate AS [ExpectedCloseDate],
       AgeInDays=OpportunityAgeDays, IsPastExpectedCloseDate AS [IsPastExpectedCloseDate],
       DaysPastDue=DaysPastExpectedCloseDate, AgeingBand AS [AgeingBand]
FROM rpt.vw_OpportunityAgeing;
GO
CREATE OR ALTER VIEW rpt.ai_LeadConversionByMonth
AS
SELECT CalendarYear AS [Year], MonthNumber AS [MonthNumber], YearMonth AS [Month],
       SalesRepID AS [SalesRepID], SalesRepName AS [SalesRepresentative], ManagerName AS [Manager],
       Region AS [Region], LeadsCreated AS [LeadsCreated], LeadsConverted AS [LeadsConverted],
       LeadConversionPct AS [LeadConversionPct]
FROM rpt.vw_LeadConversionMonthly;
GO
CREATE OR ALTER VIEW rpt.ai_SalesActivityByMonth
AS
SELECT CalendarYear AS [Year], MonthNumber AS [MonthNumber], YearMonth AS [Month],
       SalesRepID AS [SalesRepID], SalesRepName AS [SalesRepresentative], ManagerName AS [Manager],
       Region AS [Region], ActivityCount AS [ActivityCount],
       ActivityDurationMinutes AS [ActivityDurationMinutes], OpportunitiesWithActivity AS [OpportunitiesWithActivity]
FROM rpt.vw_SalesActivityMonthly;
GO
CREATE OR ALTER VIEW rpt.ai_ProductLineMargin
AS
SELECT ProductID AS [ProductID], ProductName AS [Product], Category AS [ProductCategory],
       ProductLineCount AS [ProductLineCount], ProductLineRevenueAED AS [ProductLineRevenueAED],
       EstimatedCostAED AS [EstimatedCostAED], EstimatedGrossProfitAED AS [EstimatedGrossProfitAED],
       EstimatedGrossMarginPct AS [EstimatedGrossMarginPct],
       LinesWithUnresolvedOpportunity AS [LinesWithUnresolvedOpportunity]
FROM rpt.vw_ProductLineMargin;
GO
