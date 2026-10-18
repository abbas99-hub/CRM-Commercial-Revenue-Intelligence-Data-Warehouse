/* Full-refresh Gold load. Idempotent for a fixed Silver snapshot. Do not run concurrently with reports. */
CREATE OR ALTER PROCEDURE gld.usp_LoadGold
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
  BEGIN TRAN;
  /* Delete facts before dimensions to respect FK constraints. */
  DELETE FROM gld.FactSalesTarget; DELETE FROM gld.FactLead; DELETE FROM gld.FactOpportunityProduct; DELETE FROM gld.FactActivity; DELETE FROM gld.FactOpportunity;
  DELETE FROM gld.DimContact; DELETE FROM gld.DimCampaign; DELETE FROM gld.DimProduct; DELETE FROM gld.DimSalesRep; DELETE FROM gld.DimCustomer; DELETE FROM gld.DimDate;

  SET IDENTITY_INSERT gld.DimCustomer ON;
  INSERT gld.DimCustomer(CustomerKey,AccountID,AccountName,IsUnknown) VALUES(0,'__UNKNOWN__','Unknown / unresolved',1);
  SET IDENTITY_INSERT gld.DimCustomer OFF;
  SET IDENTITY_INSERT gld.DimProduct ON;
  INSERT gld.DimProduct(ProductKey,ProductID,ProductName,IsUnknown) VALUES(0,'__UNKNOWN__','Unknown / unresolved',1);
  SET IDENTITY_INSERT gld.DimProduct OFF;
  SET IDENTITY_INSERT gld.DimSalesRep ON;
  INSERT gld.DimSalesRep(SalesRepKey,SalesRepID,SalesRepName,IsUnknown) VALUES(0,'__UNKNOWN__','Unknown / unresolved',1);
  SET IDENTITY_INSERT gld.DimSalesRep OFF;
  SET IDENTITY_INSERT gld.DimCampaign ON;
  INSERT gld.DimCampaign(CampaignKey,CampaignID,CampaignName,IsUnknown) VALUES(0,'__UNKNOWN__','Unknown / unresolved',1);
  SET IDENTITY_INSERT gld.DimCampaign OFF;
  SET IDENTITY_INSERT gld.DimContact ON;
  INSERT gld.DimContact(ContactKey,ContactID,ContactName,IsUnknown) VALUES(0,'__UNKNOWN__','Unknown / unresolved',1);
  SET IDENTITY_INSERT gld.DimContact OFF;
  INSERT gld.DimDate(DateKey,FullDate,IsUnknown) VALUES(0,NULL,1);

  INSERT gld.DimDate(DateKey,FullDate,CalendarYear,QuarterNumber,QuarterLabel,MonthNumber,MonthName,YearMonth,WeekNumber,IsMonthEnd)
  SELECT CONVERT(int,CONVERT(char(8),CalendarDate,112)),CalendarDate,CalendarYear,TRY_CONVERT(tinyint,RIGHT(CalendarQuarter,1)),CalendarQuarter,MonthNumber,MonthName,YearMonth,WeekNumber,IsMonthEnd
  FROM slv.CalendarDate;
  INSERT gld.DimCustomer(AccountID,AccountName,Industry,Country,City,Segment,TerritoryID,AnnualRevenueAED,Employees,AccountStatus)
  SELECT AccountID,AccountName,Industry,Country,City,Segment,TerritoryID,AnnualRevenueAED,Employees,AccountStatus FROM slv.Accounts;
  INSERT gld.DimProduct(ProductID,ProductName,Category,UnitPriceAED,StandardMarginPct,IsActive)
  SELECT ProductID,ProductName,Category,UnitPriceAED,StandardMarginPct,IsActive FROM slv.Products;
  INSERT gld.DimSalesRep(SalesRepID,SalesRepName,ManagerName,TerritoryID,Region,TargetAnnualAED)
  SELECT SalesRepID,SalesRepName,ManagerName,TerritoryID,Region,TargetAnnual FROM slv.SalesReps;
  INSERT gld.DimCampaign(CampaignID,CampaignName,CampaignType,StartDateKey,BudgetAED,TargetSegment)
  SELECT c.CampaignID,c.CampaignName,c.CampaignType,COALESCE(d.DateKey,0),c.BudgetAED,c.TargetSegment
  FROM slv.Campaigns c LEFT JOIN gld.DimDate d ON d.FullDate=c.StartDate;
  INSERT gld.DimContact(ContactID,AccountID,ContactName,JobTitle,EmailOptIn)
  SELECT ContactID,AccountID,ContactName,JobTitle,EmailOptIn FROM slv.Contacts;

  INSERT gld.FactOpportunity(OpportunityID,CustomerKey,SalesRepKey,CampaignKey,CreatedDateKey,ExpectedCloseDateKey,ActualCloseDateKey,Stage,ForecastCategory,Segment,Industry,ProbabilityPct,EstimatedRevenueAED,IsTrustedForPipeline,RevenueCurrency)
  SELECT o.OpportunityID,COALESCE(c.CustomerKey,0),COALESCE(r.SalesRepKey,0),COALESCE(cp.CampaignKey,0),
   COALESCE(dc.DateKey,0),COALESCE(de.DateKey,0),COALESCE(da.DateKey,0),o.Stage,o.ForecastCategory,o.Segment,o.Industry,o.ProbabilityPct,o.EstimatedRevenue,
   CASE WHEN o.Stage IN ('Closed Won','Closed Lost') AND o.EstimatedRevenue IS NOT NULL THEN 1 WHEN o.Stage IN ('Needs Analysis','Proposal','Negotiation','Qualification') AND o.EstimatedRevenue IS NOT NULL AND o.EstimatedRevenue>0 AND o.ProbabilityPct IS NOT NULL THEN 1 ELSE 0 END,'AED'
  FROM slv.Opportunities o
  LEFT JOIN gld.DimCustomer c ON c.AccountID=o.AccountID
  LEFT JOIN gld.DimSalesRep r ON r.SalesRepID=o.SalesRepID
  LEFT JOIN gld.DimCampaign cp ON cp.CampaignID=o.CampaignID
  LEFT JOIN gld.DimDate dc ON dc.FullDate=o.CreatedDate
  LEFT JOIN gld.DimDate de ON de.FullDate=o.ExpectedCloseDate
  LEFT JOIN gld.DimDate da ON da.FullDate=o.ActualCloseDate;

  INSERT gld.FactActivity(ActivityID,OpportunityID,CustomerKey,SalesRepKey,ActivityDateKey,ActivityType,Outcome,DurationMinutes)
  SELECT a.ActivityID,a.OpportunityID,COALESCE(c.CustomerKey,0),COALESCE(r.SalesRepKey,0),COALESCE(d.DateKey,0),a.ActivityType,a.Outcome,a.DurationMinutes
  FROM slv.Activities a LEFT JOIN gld.DimCustomer c ON c.AccountID=a.AccountID
   LEFT JOIN gld.DimSalesRep r ON r.SalesRepID=a.SalesRepID LEFT JOIN gld.DimDate d ON d.FullDate=a.ActivityDate;

  INSERT gld.FactOpportunityProduct(SilverOpportunityProductKey,OpportunityID,IsOpportunityResolved,ProductKey,CustomerKey,SalesRepKey,Quantity,DiscountPct,LineRevenueAED,EstimatedCostAED,SourceBronzeRowID)
  SELECT p.SilverOpportunityProductKey,p.OpportunityID,CASE WHEN o.OpportunityID IS NOT NULL THEN 1 ELSE 0 END,COALESCE(pr.ProductKey,0),COALESCE(c.CustomerKey,0),COALESCE(r.SalesRepKey,0),p.Quantity,p.DiscountPct,p.LineRevenueAED,p.EstimatedCostAED,p.SourceBronzeRowID
  FROM slv.OpportunityProducts p LEFT JOIN gld.DimProduct pr ON pr.ProductID=p.ProductID
  LEFT JOIN slv.Opportunities o ON o.OpportunityID=p.OpportunityID
  LEFT JOIN gld.DimCustomer c ON c.AccountID=o.AccountID LEFT JOIN gld.DimSalesRep r ON r.SalesRepID=o.SalesRepID;

  INSERT gld.FactLead(LeadID,CustomerKey,SalesRepKey,CreatedDateKey,ConvertedDateKey,LeadSource,Industry,LeadStatus,LeadScore)
  SELECT l.LeadID,COALESCE(c.CustomerKey,0),COALESCE(r.SalesRepKey,0),COALESCE(dc.DateKey,0),COALESCE(dv.DateKey,0),l.LeadSource,l.Industry,l.LeadStatus,l.LeadScore
  FROM slv.Leads l LEFT JOIN gld.DimCustomer c ON c.AccountID=l.AccountID LEFT JOIN gld.DimSalesRep r ON r.SalesRepID=l.SalesRepID
  LEFT JOIN gld.DimDate dc ON dc.FullDate=l.CreatedDate LEFT JOIN gld.DimDate dv ON dv.FullDate=l.ConvertedDate;

  INSERT gld.FactSalesTarget(MonthDateKey,SalesRepKey,RevenueTargetAED,PipelineTargetAED,WinRateTargetPct,TargetCurrency)
  SELECT COALESCE(d.DateKey,0),COALESCE(r.SalesRepKey,0),t.RevenueTarget,t.PipelineTarget,t.WinRateTargetPct,'AED'
  FROM slv.Targets t LEFT JOIN gld.DimDate d ON d.FullDate=t.[Month] LEFT JOIN gld.DimSalesRep r ON r.SalesRepID=t.SalesRepID;

  COMMIT;
 END TRY
 BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK;
  THROW;
 END CATCH
END;
GO
