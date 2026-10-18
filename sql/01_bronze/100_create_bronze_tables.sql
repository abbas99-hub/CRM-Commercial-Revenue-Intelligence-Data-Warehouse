/* Phase 3 Bronze raw tables. All source values remain text in Bronze to preserve source fidelity.
   Execute after sql/00_admin/010_create_schemas.sql and 020_create_control_tables.sql. */
SET NOCOUNT ON;
GO
IF OBJECT_ID('ctl.SourceFileAudit','U') IS NULL
BEGIN
 CREATE TABLE ctl.SourceFileAudit(
  SourceFileAuditID BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
  IngestionBatchID BIGINT NOT NULL, EntityName SYSNAME NOT NULL, SourcePath NVARCHAR(2048) NOT NULL,
  SourceFileName NVARCHAR(260) NOT NULL, SourceFileSizeBytes BIGINT NULL, SourceLastWriteUtc DATETIME2(3) NULL,
  ExpectedHeaderHash CHAR(64) NULL, ActualHeaderHash CHAR(64) NULL, HeaderStatus VARCHAR(20) NOT NULL,
  SourceRowCount BIGINT NULL, InsertedRowCount BIGINT NULL, AuditCreatedAtUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT FK_SourceFileAudit_Batch FOREIGN KEY (IngestionBatchID) REFERENCES ctl.IngestionBatch(IngestionBatchID));
END;
GO
IF OBJECT_ID('ctl.IngestionError','U') IS NULL
BEGIN
 CREATE TABLE ctl.IngestionError(
  IngestionErrorID BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY, IngestionBatchID BIGINT NULL, EntityName SYSNAME NULL,
  SourceFileName NVARCHAR(260) NULL, SourceRowNumber BIGINT NULL, ErrorStage VARCHAR(40) NOT NULL,
  ErrorNumber INT NULL, ErrorMessage NVARCHAR(MAX) NOT NULL, ErrorAtUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT FK_IngestionError_Batch FOREIGN KEY (IngestionBatchID) REFERENCES ctl.IngestionBatch(IngestionBatchID));
END;
GO

IF OBJECT_ID('brz.Accounts','U') IS NULL
BEGIN
 CREATE TABLE brz.[Accounts](
    BronzeRowID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_brz_Accounts PRIMARY KEY,
    IngestionBatchID BIGINT NOT NULL,
    SourceFileName NVARCHAR(260) NOT NULL,
    SourceRowNumber BIGINT NOT NULL,
    IngestedAtUtc DATETIME2(3) NOT NULL CONSTRAINT DF_brz_Accounts_IngestedAt DEFAULT SYSUTCDATETIME(),
    [AccountID] NVARCHAR(MAX) NULL,
    [AccountName] NVARCHAR(MAX) NULL,
    [Industry] NVARCHAR(MAX) NULL,
    [Country] NVARCHAR(MAX) NULL,
    [City] NVARCHAR(MAX) NULL,
    [Segment] NVARCHAR(MAX) NULL,
    [TerritoryID] NVARCHAR(MAX) NULL,
    [AnnualRevenue] NVARCHAR(MAX) NULL,
    [Employees] NVARCHAR(MAX) NULL,
    [AccountStatus] NVARCHAR(MAX) NULL,
    CONSTRAINT FK_brz_Accounts_Batch FOREIGN KEY (IngestionBatchID) REFERENCES ctl.IngestionBatch(IngestionBatchID)
 );
END;
GO

IF OBJECT_ID('brz.Activities','U') IS NULL
BEGIN
 CREATE TABLE brz.[Activities](
    BronzeRowID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_brz_Activities PRIMARY KEY,
    IngestionBatchID BIGINT NOT NULL,
    SourceFileName NVARCHAR(260) NOT NULL,
    SourceRowNumber BIGINT NOT NULL,
    IngestedAtUtc DATETIME2(3) NOT NULL CONSTRAINT DF_brz_Activities_IngestedAt DEFAULT SYSUTCDATETIME(),
    [ActivityID] NVARCHAR(MAX) NULL,
    [OpportunityID] NVARCHAR(MAX) NULL,
    [AccountID] NVARCHAR(MAX) NULL,
    [SalesRepID] NVARCHAR(MAX) NULL,
    [ActivityDate] NVARCHAR(MAX) NULL,
    [ActivityType] NVARCHAR(MAX) NULL,
    [Outcome] NVARCHAR(MAX) NULL,
    [DurationMinutes] NVARCHAR(MAX) NULL,
    CONSTRAINT FK_brz_Activities_Batch FOREIGN KEY (IngestionBatchID) REFERENCES ctl.IngestionBatch(IngestionBatchID)
 );
END;
GO

IF OBJECT_ID('brz.Campaigns','U') IS NULL
BEGIN
 CREATE TABLE brz.[Campaigns](
    BronzeRowID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_brz_Campaigns PRIMARY KEY,
    IngestionBatchID BIGINT NOT NULL,
    SourceFileName NVARCHAR(260) NOT NULL,
    SourceRowNumber BIGINT NOT NULL,
    IngestedAtUtc DATETIME2(3) NOT NULL CONSTRAINT DF_brz_Campaigns_IngestedAt DEFAULT SYSUTCDATETIME(),
    [CampaignID] NVARCHAR(MAX) NULL,
    [CampaignName] NVARCHAR(MAX) NULL,
    [CampaignType] NVARCHAR(MAX) NULL,
    [StartDate] NVARCHAR(MAX) NULL,
    [Budget] NVARCHAR(MAX) NULL,
    [TargetSegment] NVARCHAR(MAX) NULL,
    CONSTRAINT FK_brz_Campaigns_Batch FOREIGN KEY (IngestionBatchID) REFERENCES ctl.IngestionBatch(IngestionBatchID)
 );
END;
GO

IF OBJECT_ID('brz.Contacts','U') IS NULL
BEGIN
 CREATE TABLE brz.[Contacts](
    BronzeRowID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_brz_Contacts PRIMARY KEY,
    IngestionBatchID BIGINT NOT NULL,
    SourceFileName NVARCHAR(260) NOT NULL,
    SourceRowNumber BIGINT NOT NULL,
    IngestedAtUtc DATETIME2(3) NOT NULL CONSTRAINT DF_brz_Contacts_IngestedAt DEFAULT SYSUTCDATETIME(),
    [ContactID] NVARCHAR(MAX) NULL,
    [AccountID] NVARCHAR(MAX) NULL,
    [ContactName] NVARCHAR(MAX) NULL,
    [JobTitle] NVARCHAR(MAX) NULL,
    [EmailOptIn] NVARCHAR(MAX) NULL,
    CONSTRAINT FK_brz_Contacts_Batch FOREIGN KEY (IngestionBatchID) REFERENCES ctl.IngestionBatch(IngestionBatchID)
 );
END;
GO

IF OBJECT_ID('brz.Date','U') IS NULL
BEGIN
 CREATE TABLE brz.[Date](
    BronzeRowID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_brz_Date PRIMARY KEY,
    IngestionBatchID BIGINT NOT NULL,
    SourceFileName NVARCHAR(260) NOT NULL,
    SourceRowNumber BIGINT NOT NULL,
    IngestedAtUtc DATETIME2(3) NOT NULL CONSTRAINT DF_brz_Date_IngestedAt DEFAULT SYSUTCDATETIME(),
    [Date] NVARCHAR(MAX) NULL,
    [Year] NVARCHAR(MAX) NULL,
    [MonthNumber] NVARCHAR(MAX) NULL,
    [Month] NVARCHAR(MAX) NULL,
    [YearMonth] NVARCHAR(MAX) NULL,
    [Quarter] NVARCHAR(MAX) NULL,
    [WeekNumber] NVARCHAR(MAX) NULL,
    [IsMonthEnd] NVARCHAR(MAX) NULL,
    CONSTRAINT FK_brz_Date_Batch FOREIGN KEY (IngestionBatchID) REFERENCES ctl.IngestionBatch(IngestionBatchID)
 );
END;
GO

IF OBJECT_ID('brz.Leads','U') IS NULL
BEGIN
 CREATE TABLE brz.[Leads](
    BronzeRowID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_brz_Leads PRIMARY KEY,
    IngestionBatchID BIGINT NOT NULL,
    SourceFileName NVARCHAR(260) NOT NULL,
    SourceRowNumber BIGINT NOT NULL,
    IngestedAtUtc DATETIME2(3) NOT NULL CONSTRAINT DF_brz_Leads_IngestedAt DEFAULT SYSUTCDATETIME(),
    [LeadID] NVARCHAR(MAX) NULL,
    [CreatedDate] NVARCHAR(MAX) NULL,
    [AccountID] NVARCHAR(MAX) NULL,
    [LeadSource] NVARCHAR(MAX) NULL,
    [Industry] NVARCHAR(MAX) NULL,
    [LeadScore] NVARCHAR(MAX) NULL,
    [Status] NVARCHAR(MAX) NULL,
    [ConvertedDate] NVARCHAR(MAX) NULL,
    [SalesRepID] NVARCHAR(MAX) NULL,
    CONSTRAINT FK_brz_Leads_Batch FOREIGN KEY (IngestionBatchID) REFERENCES ctl.IngestionBatch(IngestionBatchID)
 );
END;
GO

IF OBJECT_ID('brz.Opportunities','U') IS NULL
BEGIN
 CREATE TABLE brz.[Opportunities](
    BronzeRowID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_brz_Opportunities PRIMARY KEY,
    IngestionBatchID BIGINT NOT NULL,
    SourceFileName NVARCHAR(260) NOT NULL,
    SourceRowNumber BIGINT NOT NULL,
    IngestedAtUtc DATETIME2(3) NOT NULL CONSTRAINT DF_brz_Opportunities_IngestedAt DEFAULT SYSUTCDATETIME(),
    [OpportunityID] NVARCHAR(MAX) NULL,
    [AccountID] NVARCHAR(MAX) NULL,
    [SalesRepID] NVARCHAR(MAX) NULL,
    [CreatedDate] NVARCHAR(MAX) NULL,
    [ExpectedCloseDate] NVARCHAR(MAX) NULL,
    [ActualCloseDate] NVARCHAR(MAX) NULL,
    [Stage] NVARCHAR(MAX) NULL,
    [EstimatedRevenue] NVARCHAR(MAX) NULL,
    [ProbabilityPct] NVARCHAR(MAX) NULL,
    [LeadSource] NVARCHAR(MAX) NULL,
    [Industry] NVARCHAR(MAX) NULL,
    [Segment] NVARCHAR(MAX) NULL,
    [CampaignID] NVARCHAR(MAX) NULL,
    [ForecastCategory] NVARCHAR(MAX) NULL,
    [CompetitorInvolved] NVARCHAR(MAX) NULL,
    CONSTRAINT FK_brz_Opportunities_Batch FOREIGN KEY (IngestionBatchID) REFERENCES ctl.IngestionBatch(IngestionBatchID)
 );
END;
GO

IF OBJECT_ID('brz.OpportunityProducts','U') IS NULL
BEGIN
 CREATE TABLE brz.[OpportunityProducts](
    BronzeRowID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_brz_OpportunityProducts PRIMARY KEY,
    IngestionBatchID BIGINT NOT NULL,
    SourceFileName NVARCHAR(260) NOT NULL,
    SourceRowNumber BIGINT NOT NULL,
    IngestedAtUtc DATETIME2(3) NOT NULL CONSTRAINT DF_brz_OpportunityProducts_IngestedAt DEFAULT SYSUTCDATETIME(),
    [OpportunityID] NVARCHAR(MAX) NULL,
    [ProductID] NVARCHAR(MAX) NULL,
    [Quantity] NVARCHAR(MAX) NULL,
    [DiscountPct] NVARCHAR(MAX) NULL,
    [LineRevenue] NVARCHAR(MAX) NULL,
    [EstimatedCost] NVARCHAR(MAX) NULL,
    CONSTRAINT FK_brz_OpportunityProducts_Batch FOREIGN KEY (IngestionBatchID) REFERENCES ctl.IngestionBatch(IngestionBatchID)
 );
END;
GO

IF OBJECT_ID('brz.Products','U') IS NULL
BEGIN
 CREATE TABLE brz.[Products](
    BronzeRowID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_brz_Products PRIMARY KEY,
    IngestionBatchID BIGINT NOT NULL,
    SourceFileName NVARCHAR(260) NOT NULL,
    SourceRowNumber BIGINT NOT NULL,
    IngestedAtUtc DATETIME2(3) NOT NULL CONSTRAINT DF_brz_Products_IngestedAt DEFAULT SYSUTCDATETIME(),
    [ProductID] NVARCHAR(MAX) NULL,
    [ProductName] NVARCHAR(MAX) NULL,
    [Category] NVARCHAR(MAX) NULL,
    [UnitPrice] NVARCHAR(MAX) NULL,
    [StandardMarginPct] NVARCHAR(MAX) NULL,
    [Active] NVARCHAR(MAX) NULL,
    CONSTRAINT FK_brz_Products_Batch FOREIGN KEY (IngestionBatchID) REFERENCES ctl.IngestionBatch(IngestionBatchID)
 );
END;
GO

IF OBJECT_ID('brz.SalesReps','U') IS NULL
BEGIN
 CREATE TABLE brz.[SalesReps](
    BronzeRowID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_brz_SalesReps PRIMARY KEY,
    IngestionBatchID BIGINT NOT NULL,
    SourceFileName NVARCHAR(260) NOT NULL,
    SourceRowNumber BIGINT NOT NULL,
    IngestedAtUtc DATETIME2(3) NOT NULL CONSTRAINT DF_brz_SalesReps_IngestedAt DEFAULT SYSUTCDATETIME(),
    [SalesRepID] NVARCHAR(MAX) NULL,
    [SalesRepName] NVARCHAR(MAX) NULL,
    [ManagerName] NVARCHAR(MAX) NULL,
    [TerritoryID] NVARCHAR(MAX) NULL,
    [Region] NVARCHAR(MAX) NULL,
    [TargetAnnual] NVARCHAR(MAX) NULL,
    CONSTRAINT FK_brz_SalesReps_Batch FOREIGN KEY (IngestionBatchID) REFERENCES ctl.IngestionBatch(IngestionBatchID)
 );
END;
GO

IF OBJECT_ID('brz.Targets','U') IS NULL
BEGIN
 CREATE TABLE brz.[Targets](
    BronzeRowID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_brz_Targets PRIMARY KEY,
    IngestionBatchID BIGINT NOT NULL,
    SourceFileName NVARCHAR(260) NOT NULL,
    SourceRowNumber BIGINT NOT NULL,
    IngestedAtUtc DATETIME2(3) NOT NULL CONSTRAINT DF_brz_Targets_IngestedAt DEFAULT SYSUTCDATETIME(),
    [Month] NVARCHAR(MAX) NULL,
    [SalesRepID] NVARCHAR(MAX) NULL,
    [RevenueTarget] NVARCHAR(MAX) NULL,
    [PipelineTarget] NVARCHAR(MAX) NULL,
    [WinRateTargetPct] NVARCHAR(MAX) NULL,
    CONSTRAINT FK_brz_Targets_Batch FOREIGN KEY (IngestionBatchID) REFERENCES ctl.IngestionBatch(IngestionBatchID)
 );
END;
GO
