/* Rebuilds current Silver opportunity/rep/target rows from Bronze.
   Conflicting OpportunityIDs are quarantined as a group; no arbitrary winner is selected.
   Requires Bronze tables and ctl.DataQualityException from 100_create_silver_tables.sql. */
CREATE OR ALTER PROCEDURE slv.usp_TransformOpportunitiesAndTargets
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRAN;
 TRUNCATE TABLE slv.Opportunities;
 TRUNCATE TABLE slv.Targets;
 DELETE FROM slv.SalesReps;
 DELETE FROM ctl.DataQualityException WHERE RuleCode LIKE 'OPP_%' OR RuleCode LIKE 'TARGET_%' OR RuleCode LIKE 'REP_%';

 ;WITH O AS (
   SELECT b.*, NULLIF(LTRIM(RTRIM(b.OpportunityID)), '') AS OID,
    COUNT(*) OVER(PARTITION BY NULLIF(LTRIM(RTRIM(b.OpportunityID)), '')) AS KeyCount
   FROM brz.Opportunities b
 ), ConflictKeys AS (
   SELECT OID FROM O WHERE KeyCount > 1 GROUP BY OID
 ), ConflictRows AS (
   SELECT o.* FROM O o JOIN ConflictKeys k ON k.OID=o.OID
 )
 INSERT ctl.DataQualityException(RuleCode,EntityName,BusinessKey,BronzeRowID,IngestionBatchID,Severity,Details)
 SELECT 'OPP_DUPLICATE_CONFLICT','Opportunities',OID,BronzeRowID,IngestionBatchID,'ERROR',
        CONCAT('OpportunityID occurs ',KeyCount,' times. All rows quarantined until authoritative resolution.')
 FROM ConflictRows;

 INSERT ctl.DataQualityException(RuleCode,EntityName,BusinessKey,BronzeRowID,IngestionBatchID,Severity,Details)
 SELECT 'OPP_INVALID_REQUIRED_KEY','Opportunities',NULL,BronzeRowID,IngestionBatchID,'ERROR','OpportunityID is null or blank.'
 FROM brz.Opportunities WHERE NULLIF(LTRIM(RTRIM(OpportunityID)), '') IS NULL;

 INSERT ctl.DataQualityException(RuleCode,EntityName,BusinessKey,BronzeRowID,IngestionBatchID,Severity,Details)
 SELECT 'OPP_INVALID_TYPED_VALUE','Opportunities',NULLIF(LTRIM(RTRIM(OpportunityID)),''),BronzeRowID,IngestionBatchID,'ERROR',
   CONCAT('Invalid typed value(s): CreatedDate=',COALESCE(CreatedDate,'NULL'),'; ExpectedCloseDate=',COALESCE(ExpectedCloseDate,'NULL'),
   '; ActualCloseDate=',COALESCE(ActualCloseDate,'NULL'),'; EstimatedRevenue=',COALESCE(EstimatedRevenue,'NULL'),'; ProbabilityPct=',COALESCE(ProbabilityPct,'NULL'))
 FROM brz.Opportunities
 WHERE (NULLIF(LTRIM(RTRIM(CreatedDate)),'') IS NOT NULL AND TRY_CONVERT(date,CreatedDate) IS NULL)
    OR (NULLIF(LTRIM(RTRIM(ExpectedCloseDate)),'') IS NOT NULL AND TRY_CONVERT(date,ExpectedCloseDate) IS NULL)
    OR (NULLIF(LTRIM(RTRIM(ActualCloseDate)),'') IS NOT NULL AND TRY_CONVERT(date,ActualCloseDate) IS NULL)
    OR (NULLIF(LTRIM(RTRIM(EstimatedRevenue)),'') IS NOT NULL AND TRY_CONVERT(decimal(19,4),EstimatedRevenue) IS NULL)
    OR (NULLIF(LTRIM(RTRIM(ProbabilityPct)),'') IS NOT NULL AND (TRY_CONVERT(decimal(9,4),ProbabilityPct) IS NULL OR TRY_CONVERT(decimal(9,4),ProbabilityPct) NOT BETWEEN 0 AND 100));

 ;WITH O AS (
  SELECT b.*, NULLIF(LTRIM(RTRIM(b.OpportunityID)), '') AS OID,
   COUNT(*) OVER(PARTITION BY NULLIF(LTRIM(RTRIM(b.OpportunityID)), '')) AS KeyCount
  FROM brz.Opportunities b
 )
 INSERT slv.Opportunities(OpportunityID,AccountID,SalesRepID,CreatedDate,ExpectedCloseDate,ActualCloseDate,Stage,EstimatedRevenue,ProbabilityPct,LeadSource,Industry,Segment,CampaignID,ForecastCategory,CompetitorInvolved,SourceBronzeRowID,IngestionBatchID)
 SELECT OID,NULLIF(LTRIM(RTRIM(AccountID)),''),NULLIF(LTRIM(RTRIM(SalesRepID)),''),
  TRY_CONVERT(date,NULLIF(LTRIM(RTRIM(CreatedDate)),'')),TRY_CONVERT(date,NULLIF(LTRIM(RTRIM(ExpectedCloseDate)),'')),TRY_CONVERT(date,NULLIF(LTRIM(RTRIM(ActualCloseDate)),'')),
  CASE UPPER(LTRIM(RTRIM(Stage))) WHEN 'CLOSED WON' THEN 'Closed Won' WHEN 'CLOSED LOST' THEN 'Closed Lost'
   WHEN 'NEEDS ANALYSIS' THEN 'Needs Analysis' WHEN 'PROPOSAL' THEN 'Proposal' WHEN 'NEGOTIATION' THEN 'Negotiation'
   WHEN 'QUALIFICATION' THEN 'Qualification' WHEN 'UNKNOWN' THEN 'Unknown' ELSE LTRIM(RTRIM(Stage)) END,
  TRY_CONVERT(decimal(19,4),NULLIF(LTRIM(RTRIM(EstimatedRevenue)),'')),TRY_CONVERT(decimal(9,4),NULLIF(LTRIM(RTRIM(ProbabilityPct)),'')),
  NULLIF(LTRIM(RTRIM(LeadSource)),''),NULLIF(LTRIM(RTRIM(Industry)),''),NULLIF(LTRIM(RTRIM(Segment)),''),NULLIF(LTRIM(RTRIM(CampaignID)),''),
  NULLIF(LTRIM(RTRIM(ForecastCategory)),''),
  CASE WHEN UPPER(LTRIM(RTRIM(CompetitorInvolved))) IN ('1','TRUE','YES','Y') THEN 1 WHEN UPPER(LTRIM(RTRIM(CompetitorInvolved))) IN ('0','FALSE','NO','N') THEN 0 ELSE NULL END,
  BronzeRowID,IngestionBatchID
 FROM O
 WHERE KeyCount=1 AND OID IS NOT NULL
  AND (NULLIF(LTRIM(RTRIM(CreatedDate)),'') IS NULL OR TRY_CONVERT(date,CreatedDate) IS NOT NULL)
  AND (NULLIF(LTRIM(RTRIM(ExpectedCloseDate)),'') IS NULL OR TRY_CONVERT(date,ExpectedCloseDate) IS NOT NULL)
  AND (NULLIF(LTRIM(RTRIM(ActualCloseDate)),'') IS NULL OR TRY_CONVERT(date,ActualCloseDate) IS NOT NULL)
  AND (NULLIF(LTRIM(RTRIM(EstimatedRevenue)),'') IS NULL OR TRY_CONVERT(decimal(19,4),EstimatedRevenue) >= 0)
  AND (NULLIF(LTRIM(RTRIM(ProbabilityPct)),'') IS NULL OR TRY_CONVERT(decimal(9,4),ProbabilityPct) BETWEEN 0 AND 100);

 INSERT ctl.DataQualityException(RuleCode,EntityName,BusinessKey,BronzeRowID,IngestionBatchID,Severity,Details)
 SELECT 'OPP_UNKNOWN_STAGE','Opportunities',OpportunityID,SourceBronzeRowID,IngestionBatchID,'ERROR','Unmapped/Unknown stage excluded from trusted pipeline and forecast totals.'
 FROM slv.Opportunities WHERE UPPER(Stage)='UNKNOWN' OR Stage NOT IN ('Closed Won','Closed Lost','Needs Analysis','Proposal','Negotiation','Qualification');
 INSERT ctl.DataQualityException(RuleCode,EntityName,BusinessKey,BronzeRowID,IngestionBatchID,Severity,Details)
 SELECT 'OPP_STAGE_FORECAST_MISMATCH','Opportunities',OpportunityID,SourceBronzeRowID,IngestionBatchID,'WARN',
  CONCAT('Stage=',Stage,'; ForecastCategory=',COALESCE(ForecastCategory,'NULL'),'. Stage governs open/closed status; category is retained separately.')
 FROM slv.Opportunities WHERE (Stage IN ('Closed Won','Closed Lost') AND ISNULL(ForecastCategory,'')<>'Closed')
  OR (Stage NOT IN ('Closed Won','Closed Lost') AND ForecastCategory='Closed');

 /* Sales rep targets are typed and validated. */
 INSERT slv.SalesReps(SalesRepID,SalesRepName,ManagerName,TerritoryID,Region,TargetAnnual,SourceBronzeRowID,IngestionBatchID)
 SELECT LTRIM(RTRIM(SalesRepID)),NULLIF(LTRIM(RTRIM(SalesRepName)),''),NULLIF(LTRIM(RTRIM(ManagerName)),''),NULLIF(LTRIM(RTRIM(TerritoryID)),''),NULLIF(LTRIM(RTRIM(Region)),''),
  TRY_CONVERT(decimal(19,4),NULLIF(LTRIM(RTRIM(TargetAnnual)),'')),BronzeRowID,IngestionBatchID
 FROM brz.SalesReps
 WHERE NULLIF(LTRIM(RTRIM(SalesRepID)),'') IS NOT NULL
  AND (NULLIF(LTRIM(RTRIM(TargetAnnual)),'') IS NULL OR TRY_CONVERT(decimal(19,4),TargetAnnual)>=0)
  AND NOT EXISTS (SELECT 1 FROM brz.SalesReps x WHERE x.SalesRepID=brz.SalesReps.SalesRepID AND x.BronzeRowID<brz.SalesReps.BronzeRowID);
 INSERT ctl.DataQualityException(RuleCode,EntityName,BusinessKey,BronzeRowID,IngestionBatchID,Severity,Details)
 SELECT 'REP_INVALID_TARGET','SalesReps',SalesRepID,BronzeRowID,IngestionBatchID,'ERROR','Annual target is not a valid non-negative decimal.'
 FROM brz.SalesReps WHERE NULLIF(LTRIM(RTRIM(TargetAnnual)),'') IS NOT NULL AND TRY_CONVERT(decimal(19,4),TargetAnnual) IS NULL OR TRY_CONVERT(decimal(19,4),TargetAnnual)<0;

 /* Targets must be one row per month + rep. Duplicate grains are quarantined as a group. */
 ;WITH T AS (SELECT b.*,COUNT(*) OVER(PARTITION BY TRY_CONVERT(date,[Month]),LTRIM(RTRIM(SalesRepID))) AS GrainCount FROM brz.Targets b)
 INSERT ctl.DataQualityException(RuleCode,EntityName,BusinessKey,BronzeRowID,IngestionBatchID,Severity,Details)
 SELECT 'TARGET_DUPLICATE_GRAIN','Targets',CONCAT(SalesRepID,'|',COALESCE([Month],'NULL')),BronzeRowID,IngestionBatchID,'ERROR','Duplicate (month, SalesRepID) grain; all rows at this grain excluded until resolved.'
 FROM T WHERE GrainCount>1;
 INSERT ctl.DataQualityException(RuleCode,EntityName,BusinessKey,BronzeRowID,IngestionBatchID,Severity,Details)
 SELECT 'TARGET_INVALID_TYPED_VALUE','Targets',CONCAT(SalesRepID,'|',COALESCE([Month],'NULL')),BronzeRowID,IngestionBatchID,'ERROR','Month or numeric target/percentage cannot be typed or is outside allowed range.'
 FROM brz.Targets WHERE TRY_CONVERT(date,[Month]) IS NULL
  OR (NULLIF(LTRIM(RTRIM(RevenueTarget)),'') IS NOT NULL AND (TRY_CONVERT(decimal(19,4),RevenueTarget) IS NULL OR TRY_CONVERT(decimal(19,4),RevenueTarget)<0))
  OR (NULLIF(LTRIM(RTRIM(PipelineTarget)),'') IS NOT NULL AND (TRY_CONVERT(decimal(19,4),PipelineTarget) IS NULL OR TRY_CONVERT(decimal(19,4),PipelineTarget)<0))
  OR (NULLIF(LTRIM(RTRIM(WinRateTargetPct)),'') IS NOT NULL AND (TRY_CONVERT(decimal(9,4),WinRateTargetPct) IS NULL OR TRY_CONVERT(decimal(9,4),WinRateTargetPct) NOT BETWEEN 0 AND 100));
 ;WITH T AS (SELECT b.*,COUNT(*) OVER(PARTITION BY TRY_CONVERT(date,[Month]),LTRIM(RTRIM(SalesRepID))) AS GrainCount FROM brz.Targets b)
 INSERT slv.Targets([Month],SalesRepID,RevenueTarget,PipelineTarget,WinRateTargetPct,SourceBronzeRowID,IngestionBatchID)
 SELECT TRY_CONVERT(date,[Month]),LTRIM(RTRIM(SalesRepID)),TRY_CONVERT(decimal(19,4),RevenueTarget),TRY_CONVERT(decimal(19,4),PipelineTarget),CASE WHEN TRY_CONVERT(decimal(9,4),WinRateTargetPct) > 1 THEN TRY_CONVERT(decimal(9,4),WinRateTargetPct)/100.0 ELSE TRY_CONVERT(decimal(9,4),WinRateTargetPct) END,BronzeRowID,IngestionBatchID
 FROM T WHERE GrainCount=1 AND TRY_CONVERT(date,[Month]) IS NOT NULL
  AND NULLIF(LTRIM(RTRIM(SalesRepID)),'') IS NOT NULL
  AND (NULLIF(LTRIM(RTRIM(RevenueTarget)),'') IS NULL OR TRY_CONVERT(decimal(19,4),RevenueTarget)>=0)
  AND (NULLIF(LTRIM(RTRIM(PipelineTarget)),'') IS NULL OR TRY_CONVERT(decimal(19,4),PipelineTarget)>=0)
  AND (NULLIF(LTRIM(RTRIM(WinRateTargetPct)),'') IS NULL OR (TRY_CONVERT(decimal(9,4),WinRateTargetPct) IS NOT NULL AND TRY_CONVERT(decimal(9,4),WinRateTargetPct) BETWEEN 0 AND 100));

 /* Reconcile annual target to the sum of monthly revenue targets, only for full 12-month years. */
 DELETE FROM ctl.TargetReconciliation;
 ;WITH Monthly AS (
  SELECT SalesRepID,YEAR([Month]) AS TargetYear,SUM(RevenueTarget) AS MonthlySum,COUNT(DISTINCT MONTH([Month])) AS MonthsPresent
  FROM slv.Targets GROUP BY SalesRepID,YEAR([Month])
 )
 INSERT ctl.TargetReconciliation(SalesRepID,TargetYear,AnnualTarget,MonthlyTargetSum,MonthsPresent,ExpectedMonths,DifferenceAmount,ReconciliationStatus)
 SELECT m.SalesRepID,m.TargetYear,r.TargetAnnual,m.MonthlySum,m.MonthsPresent,12,
  CASE WHEN r.TargetAnnual IS NULL THEN NULL ELSE m.MonthlySum-r.TargetAnnual END,
  CASE WHEN r.TargetAnnual IS NULL THEN 'MISSING_ANNUAL_TARGET'
       WHEN m.MonthsPresent<12 THEN 'PARTIAL_YEAR_NOT_COMPARABLE'
       WHEN ABS(m.MonthlySum-r.TargetAnnual)<=0.005 THEN 'MATCH'
       WHEN ABS(m.MonthlySum-r.TargetAnnual)<=0.05 THEN 'MATCH_WITH_ROUNDING_TOLERANCE'
       ELSE 'MISMATCH_REVIEW' END
 FROM Monthly m LEFT JOIN slv.SalesReps r ON r.SalesRepID=m.SalesRepID;
 COMMIT;
END;
GO
