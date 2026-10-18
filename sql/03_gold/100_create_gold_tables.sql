/* Phase 5: Gold dimensional model. SQL Server. Run after Phase 4 Silver objects exist. */
SET NOCOUNT ON;

IF OBJECT_ID('gld.DimCustomer','U') IS NULL CREATE TABLE gld.DimCustomer(
 CustomerKey INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_gld_DimCustomer PRIMARY KEY,
 AccountID NVARCHAR(100) NOT NULL, AccountName NVARCHAR(250) NULL, Industry NVARCHAR(100) NULL,
 Country NVARCHAR(100) NULL, City NVARCHAR(100) NULL, Segment NVARCHAR(100) NULL, TerritoryID NVARCHAR(100) NULL,
 AnnualRevenueAED DECIMAL(19,4) NULL, Employees INT NULL, AccountStatus NVARCHAR(50) NULL,
 IsUnknown BIT NOT NULL CONSTRAINT DF_gld_DimCustomer_IsUnknown DEFAULT(0), LoadedAtUtc DATETIME2(3) NOT NULL CONSTRAINT DF_gld_DimCustomer_LoadedAt DEFAULT SYSUTCDATETIME(),
 CONSTRAINT UQ_gld_DimCustomer_AccountID UNIQUE(AccountID));
GO
IF OBJECT_ID('gld.DimProduct','U') IS NULL CREATE TABLE gld.DimProduct(
 ProductKey INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_gld_DimProduct PRIMARY KEY,
 ProductID NVARCHAR(100) NOT NULL, ProductName NVARCHAR(250) NULL, Category NVARCHAR(100) NULL,
 UnitPriceAED DECIMAL(19,4) NULL, StandardMarginPct DECIMAL(9,4) NULL, IsActive BIT NULL,
 IsUnknown BIT NOT NULL CONSTRAINT DF_gld_DimProduct_IsUnknown DEFAULT(0), LoadedAtUtc DATETIME2(3) NOT NULL CONSTRAINT DF_gld_DimProduct_LoadedAt DEFAULT SYSUTCDATETIME(),
 CONSTRAINT UQ_gld_DimProduct_ProductID UNIQUE(ProductID));
GO
IF OBJECT_ID('gld.DimSalesRep','U') IS NULL CREATE TABLE gld.DimSalesRep(
 SalesRepKey INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_gld_DimSalesRep PRIMARY KEY,
 SalesRepID NVARCHAR(100) NOT NULL, SalesRepName NVARCHAR(200) NULL, ManagerName NVARCHAR(200) NULL,
 TerritoryID NVARCHAR(100) NULL, Region NVARCHAR(100) NULL, TargetAnnualAED DECIMAL(19,4) NULL,
 IsUnknown BIT NOT NULL CONSTRAINT DF_gld_DimSalesRep_IsUnknown DEFAULT(0), LoadedAtUtc DATETIME2(3) NOT NULL CONSTRAINT DF_gld_DimSalesRep_LoadedAt DEFAULT SYSUTCDATETIME(),
 CONSTRAINT UQ_gld_DimSalesRep_SalesRepID UNIQUE(SalesRepID));
GO
IF OBJECT_ID('gld.DimCampaign','U') IS NULL CREATE TABLE gld.DimCampaign(
 CampaignKey INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_gld_DimCampaign PRIMARY KEY,
 CampaignID NVARCHAR(100) NOT NULL, CampaignName NVARCHAR(250) NULL, CampaignType NVARCHAR(100) NULL,
 StartDateKey INT NULL, BudgetAED DECIMAL(19,4) NULL, TargetSegment NVARCHAR(100) NULL,
 IsUnknown BIT NOT NULL CONSTRAINT DF_gld_DimCampaign_IsUnknown DEFAULT(0), LoadedAtUtc DATETIME2(3) NOT NULL CONSTRAINT DF_gld_DimCampaign_LoadedAt DEFAULT SYSUTCDATETIME(),
 CONSTRAINT UQ_gld_DimCampaign_CampaignID UNIQUE(CampaignID));
GO
IF OBJECT_ID('gld.DimContact','U') IS NULL CREATE TABLE gld.DimContact(
 ContactKey INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_gld_DimContact PRIMARY KEY,
 ContactID NVARCHAR(100) NOT NULL, AccountID NVARCHAR(100) NULL, ContactName NVARCHAR(250) NULL,
 JobTitle NVARCHAR(150) NULL, EmailOptIn BIT NULL,
 IsUnknown BIT NOT NULL CONSTRAINT DF_gld_DimContact_IsUnknown DEFAULT(0), LoadedAtUtc DATETIME2(3) NOT NULL CONSTRAINT DF_gld_DimContact_LoadedAt DEFAULT SYSUTCDATETIME(),
 CONSTRAINT UQ_gld_DimContact_ContactID UNIQUE(ContactID));
GO
IF OBJECT_ID('gld.DimDate','U') IS NULL CREATE TABLE gld.DimDate(
 DateKey INT NOT NULL CONSTRAINT PK_gld_DimDate PRIMARY KEY, FullDate DATE NULL, CalendarYear SMALLINT NULL,
 QuarterNumber TINYINT NULL, QuarterLabel NVARCHAR(10) NULL, MonthNumber TINYINT NULL, MonthName NVARCHAR(20) NULL,
 YearMonth CHAR(7) NULL, WeekNumber TINYINT NULL, IsMonthEnd BIT NULL, IsUnknown BIT NOT NULL CONSTRAINT DF_gld_DimDate_IsUnknown DEFAULT(0),
 CONSTRAINT UQ_gld_DimDate_FullDate UNIQUE(FullDate));
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_gld_DimCampaign_StartDate')
 ALTER TABLE gld.DimCampaign ADD CONSTRAINT FK_gld_DimCampaign_StartDate FOREIGN KEY(StartDateKey) REFERENCES gld.DimDate(DateKey);
GO

/* Fact grains are explicitly enforced by their business/surrogate keys. */
IF OBJECT_ID('gld.FactOpportunity','U') IS NULL CREATE TABLE gld.FactOpportunity(
 FactOpportunityKey BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_gld_FactOpportunity PRIMARY KEY,
 OpportunityID NVARCHAR(100) NOT NULL,
 CustomerKey INT NOT NULL, SalesRepKey INT NOT NULL, CampaignKey INT NOT NULL,
 CreatedDateKey INT NOT NULL, ExpectedCloseDateKey INT NOT NULL, ActualCloseDateKey INT NOT NULL,
 Stage NVARCHAR(50) NOT NULL, ForecastCategory NVARCHAR(50) NULL, Segment NVARCHAR(100) NULL, Industry NVARCHAR(100) NULL,
 ProbabilityPct DECIMAL(9,4) NULL, EstimatedRevenueAED DECIMAL(19,4) NULL,
 WonRevenueAED AS (CASE WHEN Stage='Closed Won' THEN EstimatedRevenueAED ELSE CONVERT(DECIMAL(19,4),0) END) PERSISTED,
 WeightedPipelineAED AS (CASE WHEN Stage IN ('Needs Analysis','Proposal','Negotiation','Qualification') AND ProbabilityPct BETWEEN 0 AND 100 THEN EstimatedRevenueAED*ProbabilityPct/100.0 ELSE CONVERT(DECIMAL(19,4),0) END) PERSISTED,
 IsTrustedForPipeline BIT NOT NULL, RevenueCurrency CHAR(3) NOT NULL CONSTRAINT DF_gld_FactOpportunity_Currency DEFAULT('AED'),
 CONSTRAINT UQ_gld_FactOpportunity_OpportunityID UNIQUE(OpportunityID),
 CONSTRAINT FK_gld_FactOpportunity_Customer FOREIGN KEY(CustomerKey) REFERENCES gld.DimCustomer(CustomerKey),
 CONSTRAINT FK_gld_FactOpportunity_SalesRep FOREIGN KEY(SalesRepKey) REFERENCES gld.DimSalesRep(SalesRepKey),
 CONSTRAINT FK_gld_FactOpportunity_Campaign FOREIGN KEY(CampaignKey) REFERENCES gld.DimCampaign(CampaignKey),
 CONSTRAINT FK_gld_FactOpportunity_CreatedDate FOREIGN KEY(CreatedDateKey) REFERENCES gld.DimDate(DateKey),
 CONSTRAINT FK_gld_FactOpportunity_ExpectedDate FOREIGN KEY(ExpectedCloseDateKey) REFERENCES gld.DimDate(DateKey),
 CONSTRAINT FK_gld_FactOpportunity_ActualDate FOREIGN KEY(ActualCloseDateKey) REFERENCES gld.DimDate(DateKey));
GO
IF OBJECT_ID('gld.FactActivity','U') IS NULL CREATE TABLE gld.FactActivity(
 FactActivityKey BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_gld_FactActivity PRIMARY KEY,
 ActivityID NVARCHAR(100) NOT NULL, OpportunityID NVARCHAR(100) NULL,
 CustomerKey INT NOT NULL, SalesRepKey INT NOT NULL, ActivityDateKey INT NOT NULL,
 ActivityType NVARCHAR(100) NULL, Outcome NVARCHAR(100) NULL, DurationMinutes INT NULL,
 ActivityCount INT NOT NULL CONSTRAINT DF_gld_FactActivity_Count DEFAULT(1),
 CONSTRAINT UQ_gld_FactActivity_ActivityID UNIQUE(ActivityID),
 CONSTRAINT FK_gld_FactActivity_Customer FOREIGN KEY(CustomerKey) REFERENCES gld.DimCustomer(CustomerKey),
 CONSTRAINT FK_gld_FactActivity_SalesRep FOREIGN KEY(SalesRepKey) REFERENCES gld.DimSalesRep(SalesRepKey),
 CONSTRAINT FK_gld_FactActivity_Date FOREIGN KEY(ActivityDateKey) REFERENCES gld.DimDate(DateKey));
GO
IF OBJECT_ID('gld.FactOpportunityProduct','U') IS NULL CREATE TABLE gld.FactOpportunityProduct(
 FactOpportunityProductKey BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_gld_FactOpportunityProduct PRIMARY KEY,
 SilverOpportunityProductKey BIGINT NOT NULL, OpportunityID NVARCHAR(100) NOT NULL, IsOpportunityResolved BIT NOT NULL,
 ProductKey INT NOT NULL, CustomerKey INT NOT NULL, SalesRepKey INT NOT NULL,
 Quantity DECIMAL(19,4) NULL, DiscountPct DECIMAL(9,4) NULL, LineRevenueAED DECIMAL(19,4) NULL, EstimatedCostAED DECIMAL(19,4) NULL,
 SourceBronzeRowID BIGINT NOT NULL,
 CONSTRAINT UQ_gld_FactOpportunityProduct_SilverLine UNIQUE(SilverOpportunityProductKey),
 CONSTRAINT FK_gld_FactOpportunityProduct_Product FOREIGN KEY(ProductKey) REFERENCES gld.DimProduct(ProductKey),
 CONSTRAINT FK_gld_FactOpportunityProduct_Customer FOREIGN KEY(CustomerKey) REFERENCES gld.DimCustomer(CustomerKey),
 CONSTRAINT FK_gld_FactOpportunityProduct_SalesRep FOREIGN KEY(SalesRepKey) REFERENCES gld.DimSalesRep(SalesRepKey));
GO
IF OBJECT_ID('gld.FactLead','U') IS NULL CREATE TABLE gld.FactLead(
 FactLeadKey BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_gld_FactLead PRIMARY KEY,
 LeadID NVARCHAR(100) NOT NULL, CustomerKey INT NOT NULL, SalesRepKey INT NOT NULL,
 CreatedDateKey INT NOT NULL, ConvertedDateKey INT NOT NULL, LeadSource NVARCHAR(100) NULL, Industry NVARCHAR(100) NULL,
 LeadStatus NVARCHAR(50) NOT NULL, LeadScore DECIMAL(9,4) NULL, LeadCount INT NOT NULL CONSTRAINT DF_gld_FactLead_Count DEFAULT(1),
 CONSTRAINT UQ_gld_FactLead_LeadID UNIQUE(LeadID),
 CONSTRAINT FK_gld_FactLead_Customer FOREIGN KEY(CustomerKey) REFERENCES gld.DimCustomer(CustomerKey),
 CONSTRAINT FK_gld_FactLead_SalesRep FOREIGN KEY(SalesRepKey) REFERENCES gld.DimSalesRep(SalesRepKey),
 CONSTRAINT FK_gld_FactLead_CreatedDate FOREIGN KEY(CreatedDateKey) REFERENCES gld.DimDate(DateKey),
 CONSTRAINT FK_gld_FactLead_ConvertedDate FOREIGN KEY(ConvertedDateKey) REFERENCES gld.DimDate(DateKey));
GO
IF OBJECT_ID('gld.FactSalesTarget','U') IS NULL CREATE TABLE gld.FactSalesTarget(
 FactSalesTargetKey BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_gld_FactSalesTarget PRIMARY KEY,
 MonthDateKey INT NOT NULL, SalesRepKey INT NOT NULL, RevenueTargetAED DECIMAL(19,4) NULL, PipelineTargetAED DECIMAL(19,4) NULL,
 WinRateTargetPct DECIMAL(9,4) NULL, TargetCurrency CHAR(3) NOT NULL CONSTRAINT DF_gld_FactSalesTarget_Currency DEFAULT('AED'),
 CONSTRAINT UQ_gld_FactSalesTarget_RepMonth UNIQUE(SalesRepKey,MonthDateKey),
 CONSTRAINT FK_gld_FactSalesTarget_Date FOREIGN KEY(MonthDateKey) REFERENCES gld.DimDate(DateKey),
 CONSTRAINT FK_gld_FactSalesTarget_SalesRep FOREIGN KEY(SalesRepKey) REFERENCES gld.DimSalesRep(SalesRepKey));
GO
