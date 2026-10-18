/* Phase 4 Silver objects. Execute after Phase 3 Bronze objects in the same database. */
SET NOCOUNT ON;
IF OBJECT_ID('ctl.DataQualityException','U') IS NULL
CREATE TABLE ctl.DataQualityException(
  DataQualityExceptionID BIGINT IDENTITY(1,1) PRIMARY KEY,
  RuleCode VARCHAR(80) NOT NULL, EntityName SYSNAME NOT NULL,
  BusinessKey NVARCHAR(300) NULL, BronzeRowID BIGINT NULL, IngestionBatchID BIGINT NULL,
  Severity VARCHAR(10) NOT NULL, ExceptionStatus VARCHAR(20) NOT NULL DEFAULT 'OPEN',
  Details NVARCHAR(MAX) NOT NULL, DetectedAtUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
  ResolvedAtUtc DATETIME2(3) NULL, ResolutionNote NVARCHAR(2000) NULL
);
GO
IF OBJECT_ID('slv.Opportunities','U') IS NULL
CREATE TABLE slv.Opportunities(
  SilverOpportunityKey BIGINT IDENTITY(1,1) PRIMARY KEY,
  OpportunityID NVARCHAR(100) NOT NULL,
  AccountID NVARCHAR(100) NULL, SalesRepID NVARCHAR(100) NULL,
  CreatedDate DATE NULL, ExpectedCloseDate DATE NULL, ActualCloseDate DATE NULL,
  Stage NVARCHAR(50) NOT NULL, EstimatedRevenue DECIMAL(19,4) NULL,
  ProbabilityPct DECIMAL(9,4) NULL, LeadSource NVARCHAR(100) NULL,
  Industry NVARCHAR(100) NULL, Segment NVARCHAR(100) NULL, CampaignID NVARCHAR(100) NULL,
  ForecastCategory NVARCHAR(50) NULL, CompetitorInvolved BIT NULL,
  RevenueCurrency CHAR(3) NOT NULL CONSTRAINT DF_slv_Opportunities_Currency DEFAULT 'AED',
  SourceBronzeRowID BIGINT NOT NULL, IngestionBatchID BIGINT NOT NULL,
  TransformedAtUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT CK_slv_Opportunities_Probability CHECK (ProbabilityPct IS NULL OR ProbabilityPct BETWEEN 0 AND 100),
  CONSTRAINT CK_slv_Opportunities_Revenue CHECK (EstimatedRevenue IS NULL OR EstimatedRevenue >= 0)
);
GO
IF OBJECT_ID('slv.SalesReps','U') IS NULL
CREATE TABLE slv.SalesReps(
  SalesRepID NVARCHAR(100) NOT NULL PRIMARY KEY, SalesRepName NVARCHAR(200) NULL,
  ManagerName NVARCHAR(200) NULL, TerritoryID NVARCHAR(100) NULL, Region NVARCHAR(100) NULL,
  TargetAnnual DECIMAL(19,4) NULL, TargetCurrency CHAR(3) NOT NULL DEFAULT 'AED',
  SourceBronzeRowID BIGINT NOT NULL, IngestionBatchID BIGINT NOT NULL,
  TransformedAtUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT CK_slv_SalesReps_TargetAnnual CHECK (TargetAnnual IS NULL OR TargetAnnual >= 0)
);
GO
IF OBJECT_ID('slv.Targets','U') IS NULL
CREATE TABLE slv.Targets(
  TargetKey BIGINT IDENTITY(1,1) PRIMARY KEY, [Month] DATE NOT NULL, SalesRepID NVARCHAR(100) NOT NULL,
  RevenueTarget DECIMAL(19,4) NULL, PipelineTarget DECIMAL(19,4) NULL,
  WinRateTargetPct DECIMAL(9,4) NULL, TargetCurrency CHAR(3) NOT NULL DEFAULT 'AED',
  SourceBronzeRowID BIGINT NOT NULL, IngestionBatchID BIGINT NOT NULL,
  TransformedAtUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT CK_slv_Targets_RevenueTarget CHECK (RevenueTarget IS NULL OR RevenueTarget >= 0),
  CONSTRAINT CK_slv_Targets_PipelineTarget CHECK (PipelineTarget IS NULL OR PipelineTarget >= 0),
  CONSTRAINT CK_slv_Targets_WinRate CHECK (WinRateTargetPct IS NULL OR WinRateTargetPct BETWEEN 0 AND 1 OR WinRateTargetPct BETWEEN 0 AND 100)
);
GO
IF OBJECT_ID('ctl.TargetReconciliation','U') IS NULL
CREATE TABLE ctl.TargetReconciliation(
  TargetReconciliationID BIGINT IDENTITY(1,1) PRIMARY KEY, SalesRepID NVARCHAR(100) NOT NULL,
  TargetYear INT NOT NULL, AnnualTarget DECIMAL(19,4) NULL, MonthlyTargetSum DECIMAL(19,4) NULL,
  MonthsPresent INT NOT NULL, ExpectedMonths INT NOT NULL DEFAULT 12,
  DifferenceAmount DECIMAL(19,4) NULL, ReconciliationStatus VARCHAR(30) NOT NULL,
  Currency CHAR(3) NOT NULL DEFAULT 'AED', CalculatedAtUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO
