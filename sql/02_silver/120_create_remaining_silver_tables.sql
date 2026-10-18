/* Phase 4 completion: typed Silver tables for the remaining eight entities.
   Execute after 100_create_silver_tables.sql. Raw values remain untouched in Bronze. */
SET NOCOUNT ON;
IF OBJECT_ID('slv.Accounts','U') IS NULL CREATE TABLE slv.Accounts(
 SilverAccountKey BIGINT IDENTITY(1,1) PRIMARY KEY, AccountID NVARCHAR(100) NOT NULL,
 AccountName NVARCHAR(250) NULL, Industry NVARCHAR(100) NULL, Country NVARCHAR(100) NULL, City NVARCHAR(100) NULL,
 Segment NVARCHAR(100) NULL, TerritoryID NVARCHAR(100) NULL, AnnualRevenueAED DECIMAL(19,4) NULL, Employees INT NULL,
 AccountStatus NVARCHAR(50) NULL, SourceBronzeRowID BIGINT NOT NULL, IngestionBatchID BIGINT NOT NULL, TransformedAtUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT UQ_slv_Accounts_AccountID UNIQUE(AccountID), CONSTRAINT CK_slv_Accounts_Revenue CHECK(AnnualRevenueAED IS NULL OR AnnualRevenueAED>=0), CONSTRAINT CK_slv_Accounts_Employees CHECK(Employees IS NULL OR Employees>=0));
GO
IF OBJECT_ID('slv.Activities','U') IS NULL CREATE TABLE slv.Activities(
 SilverActivityKey BIGINT IDENTITY(1,1) PRIMARY KEY, ActivityID NVARCHAR(100) NOT NULL, OpportunityID NVARCHAR(100) NULL, AccountID NVARCHAR(100) NULL, SalesRepID NVARCHAR(100) NULL,
 ActivityDate DATE NULL, ActivityType NVARCHAR(100) NULL, Outcome NVARCHAR(100) NULL, DurationMinutes INT NULL,
 SourceBronzeRowID BIGINT NOT NULL, IngestionBatchID BIGINT NOT NULL, TransformedAtUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT UQ_slv_Activities_ActivityID UNIQUE(ActivityID), CONSTRAINT CK_slv_Activities_Duration CHECK(DurationMinutes IS NULL OR DurationMinutes>=0));
GO
IF OBJECT_ID('slv.Campaigns','U') IS NULL CREATE TABLE slv.Campaigns(
 SilverCampaignKey BIGINT IDENTITY(1,1) PRIMARY KEY, CampaignID NVARCHAR(100) NOT NULL, CampaignName NVARCHAR(250) NULL, CampaignType NVARCHAR(100) NULL,
 StartDate DATE NULL, BudgetAED DECIMAL(19,4) NULL, TargetSegment NVARCHAR(100) NULL, SourceBronzeRowID BIGINT NOT NULL, IngestionBatchID BIGINT NOT NULL,
 TransformedAtUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(), CONSTRAINT UQ_slv_Campaigns_CampaignID UNIQUE(CampaignID), CONSTRAINT CK_slv_Campaigns_Budget CHECK(BudgetAED IS NULL OR BudgetAED>=0));
GO
IF OBJECT_ID('slv.Contacts','U') IS NULL CREATE TABLE slv.Contacts(
 SilverContactKey BIGINT IDENTITY(1,1) PRIMARY KEY, ContactID NVARCHAR(100) NOT NULL, AccountID NVARCHAR(100) NULL, ContactName NVARCHAR(250) NULL,
 JobTitle NVARCHAR(150) NULL, EmailOptIn BIT NULL, SourceBronzeRowID BIGINT NOT NULL, IngestionBatchID BIGINT NOT NULL, TransformedAtUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT UQ_slv_Contacts_ContactID UNIQUE(ContactID));
GO
IF OBJECT_ID('slv.CalendarDate','U') IS NULL CREATE TABLE slv.CalendarDate(
 SilverDateKey INT NOT NULL PRIMARY KEY, CalendarDate DATE NOT NULL UNIQUE, CalendarYear SMALLINT NULL, MonthNumber TINYINT NULL, MonthName NVARCHAR(20) NULL,
 YearMonth CHAR(7) NULL, CalendarQuarter NVARCHAR(10) NULL, WeekNumber TINYINT NULL, IsMonthEnd BIT NULL,
 SourceBronzeRowID BIGINT NOT NULL, IngestionBatchID BIGINT NOT NULL, TransformedAtUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT CK_slv_CalendarDate_Month CHECK(MonthNumber IS NULL OR MonthNumber BETWEEN 1 AND 12), CONSTRAINT CK_slv_CalendarDate_Week CHECK(WeekNumber IS NULL OR WeekNumber BETWEEN 1 AND 53));
GO
IF OBJECT_ID('slv.Leads','U') IS NULL CREATE TABLE slv.Leads(
 SilverLeadKey BIGINT IDENTITY(1,1) PRIMARY KEY, LeadID NVARCHAR(100) NOT NULL, CreatedDate DATE NULL, AccountID NVARCHAR(100) NULL,
 LeadSource NVARCHAR(100) NULL, Industry NVARCHAR(100) NULL, LeadScore DECIMAL(9,4) NULL, LeadStatus NVARCHAR(50) NOT NULL,
 ConvertedDate DATE NULL, SalesRepID NVARCHAR(100) NULL, SourceBronzeRowID BIGINT NOT NULL, IngestionBatchID BIGINT NOT NULL,
 TransformedAtUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(), CONSTRAINT UQ_slv_Leads_LeadID UNIQUE(LeadID),
 CONSTRAINT CK_slv_Leads_Score CHECK(LeadScore IS NULL OR LeadScore BETWEEN 0 AND 100));
GO
IF OBJECT_ID('slv.OpportunityProducts','U') IS NULL CREATE TABLE slv.OpportunityProducts(
 SilverOpportunityProductKey BIGINT IDENTITY(1,1) PRIMARY KEY, OpportunityID NVARCHAR(100) NOT NULL, ProductID NVARCHAR(100) NOT NULL,
 Quantity DECIMAL(19,4) NULL, DiscountPct DECIMAL(9,4) NULL, LineRevenueAED DECIMAL(19,4) NULL, EstimatedCostAED DECIMAL(19,4) NULL,
 SourceBronzeRowID BIGINT NOT NULL, IngestionBatchID BIGINT NOT NULL, TransformedAtUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 CONSTRAINT CK_slv_OpportunityProducts_Qty CHECK(Quantity IS NULL OR Quantity>=0), CONSTRAINT CK_slv_OpportunityProducts_Discount CHECK(DiscountPct IS NULL OR DiscountPct BETWEEN 0 AND 100),
 CONSTRAINT CK_slv_OpportunityProducts_Revenue CHECK(LineRevenueAED IS NULL OR LineRevenueAED>=0), CONSTRAINT CK_slv_OpportunityProducts_Cost CHECK(EstimatedCostAED IS NULL OR EstimatedCostAED>=0));
GO
IF OBJECT_ID('slv.Products','U') IS NULL CREATE TABLE slv.Products(
 SilverProductKey BIGINT IDENTITY(1,1) PRIMARY KEY, ProductID NVARCHAR(100) NOT NULL, ProductName NVARCHAR(250) NULL, Category NVARCHAR(100) NULL,
 UnitPriceAED DECIMAL(19,4) NULL, StandardMarginPct DECIMAL(9,4) NULL, IsActive BIT NULL, SourceBronzeRowID BIGINT NOT NULL, IngestionBatchID BIGINT NOT NULL,
 TransformedAtUtc DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(), CONSTRAINT UQ_slv_Products_ProductID UNIQUE(ProductID),
 CONSTRAINT CK_slv_Products_UnitPrice CHECK(UnitPriceAED IS NULL OR UnitPriceAED>=0), CONSTRAINT CK_slv_Products_Margin CHECK(StandardMarginPct IS NULL OR StandardMarginPct BETWEEN 0 AND 100));
GO
