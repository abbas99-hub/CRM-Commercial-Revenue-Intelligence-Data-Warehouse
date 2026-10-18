/* Execute after gld.usp_LoadGold. Any nonzero orphan/duplicate result is a failure. */
SET NOCOUNT ON;
-- Row counts at expected grains
SELECT 'DimCustomer' EntityName,COUNT_BIG(*) RowCount,COUNT_BIG(DISTINCT AccountID) DistinctBusinessKeys FROM gld.DimCustomer WHERE IsUnknown=0
UNION ALL SELECT 'DimProduct',COUNT_BIG(*),COUNT_BIG(DISTINCT ProductID) FROM gld.DimProduct WHERE IsUnknown=0
UNION ALL SELECT 'DimSalesRep',COUNT_BIG(*),COUNT_BIG(DISTINCT SalesRepID) FROM gld.DimSalesRep WHERE IsUnknown=0
UNION ALL SELECT 'DimCampaign',COUNT_BIG(*),COUNT_BIG(DISTINCT CampaignID) FROM gld.DimCampaign WHERE IsUnknown=0
UNION ALL SELECT 'DimContact',COUNT_BIG(*),COUNT_BIG(DISTINCT ContactID) FROM gld.DimContact WHERE IsUnknown=0
UNION ALL SELECT 'DimDate',COUNT_BIG(*),COUNT_BIG(DISTINCT FullDate) FROM gld.DimDate WHERE IsUnknown=0
UNION ALL SELECT 'FactOpportunity',COUNT_BIG(*),COUNT_BIG(DISTINCT OpportunityID) FROM gld.FactOpportunity
UNION ALL SELECT 'FactActivity',COUNT_BIG(*),COUNT_BIG(DISTINCT ActivityID) FROM gld.FactActivity
UNION ALL SELECT 'FactOpportunityProduct',COUNT_BIG(*),COUNT_BIG(DISTINCT SilverOpportunityProductKey) FROM gld.FactOpportunityProduct
UNION ALL SELECT 'FactLead',COUNT_BIG(*),COUNT_BIG(DISTINCT LeadID) FROM gld.FactLead
UNION ALL SELECT 'FactSalesTarget',COUNT_BIG(*),COUNT_BIG(DISTINCT CONCAT(SalesRepKey,'|',MonthDateKey)) FROM gld.FactSalesTarget;

-- Relationship orphan checks. FKs should prevent these, but keep as acceptance evidence.
SELECT 'FactOpportunity.CustomerKey' CheckName,COUNT_BIG(*) OrphanRows FROM gld.FactOpportunity f LEFT JOIN gld.DimCustomer d ON d.CustomerKey=f.CustomerKey WHERE d.CustomerKey IS NULL
UNION ALL SELECT 'FactOpportunity.SalesRepKey',COUNT_BIG(*) FROM gld.FactOpportunity f LEFT JOIN gld.DimSalesRep d ON d.SalesRepKey=f.SalesRepKey WHERE d.SalesRepKey IS NULL
UNION ALL SELECT 'FactOpportunity.CampaignKey',COUNT_BIG(*) FROM gld.FactOpportunity f LEFT JOIN gld.DimCampaign d ON d.CampaignKey=f.CampaignKey WHERE d.CampaignKey IS NULL
UNION ALL SELECT 'FactActivity.CustomerKey',COUNT_BIG(*) FROM gld.FactActivity f LEFT JOIN gld.DimCustomer d ON d.CustomerKey=f.CustomerKey WHERE d.CustomerKey IS NULL
UNION ALL SELECT 'FactOpportunityProduct.ProductKey',COUNT_BIG(*) FROM gld.FactOpportunityProduct f LEFT JOIN gld.DimProduct d ON d.ProductKey=f.ProductKey WHERE d.ProductKey IS NULL
UNION ALL SELECT 'FactSalesTarget.SalesRepKey',COUNT_BIG(*) FROM gld.FactSalesTarget f LEFT JOIN gld.DimSalesRep d ON d.SalesRepKey=f.SalesRepKey WHERE d.SalesRepKey IS NULL;

-- Aggregation checks: revenue measure must reconcile to validated Silver opportunities, not product line revenue.
SELECT 'Silver won revenue' Metric, SUM(EstimatedRevenue) AmountAED FROM slv.Opportunities WHERE Stage='Closed Won'
UNION ALL SELECT 'Gold won revenue',SUM(WonRevenueAED) FROM gld.FactOpportunity;
SELECT 'Silver opportunities' Metric,COUNT_BIG(*) RecordCount FROM slv.Opportunities
UNION ALL SELECT 'Gold opportunities',COUNT_BIG(*) FROM gld.FactOpportunity;
SELECT 'Silver activities' Metric,COUNT_BIG(*) RecordCount FROM slv.Activities
UNION ALL SELECT 'Gold activities',COUNT_BIG(*) FROM gld.FactActivity;
SELECT 'Silver product lines' Metric,COUNT_BIG(*) RecordCount FROM slv.OpportunityProducts
UNION ALL SELECT 'Gold product lines',COUNT_BIG(*) FROM gld.FactOpportunityProduct;
SELECT 'Silver leads' Metric,COUNT_BIG(*) RecordCount FROM slv.Leads
UNION ALL SELECT 'Gold leads',COUNT_BIG(*) FROM gld.FactLead;
SELECT 'Silver targets' Metric,COUNT_BIG(*) RecordCount FROM slv.Targets
UNION ALL SELECT 'Gold targets',COUNT_BIG(*) FROM gld.FactSalesTarget;

-- Warn about facts mapped to unknown members; not a relational orphan, but a coverage issue.
SELECT 'Opportunity unknown customer' CheckName,COUNT_BIG(*) AffectedRows FROM gld.FactOpportunity WHERE CustomerKey=0
UNION ALL SELECT 'Opportunity unknown rep',COUNT_BIG(*) FROM gld.FactOpportunity WHERE SalesRepKey=0
UNION ALL SELECT 'Opportunity unknown campaign',COUNT_BIG(*) FROM gld.FactOpportunity WHERE CampaignKey=0
UNION ALL SELECT 'Product line unknown product',COUNT_BIG(*) FROM gld.FactOpportunityProduct WHERE ProductKey=0;

-- Revenue and product-line totals are intentionally compared, not assumed equal.
SELECT 'Won EstimatedRevenue AED' Metric,SUM(WonRevenueAED) AmountAED FROM gld.FactOpportunity
UNION ALL SELECT 'Product line revenue AED',SUM(LineRevenueAED) FROM gld.FactOpportunityProduct;

-- Product lines linked to unresolved/conflicting opportunity IDs must not be treated as reconciled commercial detail.
SELECT IsOpportunityResolved,COUNT_BIG(*) LineCount,SUM(LineRevenueAED) LineRevenueAED FROM gld.FactOpportunityProduct GROUP BY IsOpportunityResolved;
