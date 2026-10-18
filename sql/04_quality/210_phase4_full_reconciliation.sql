/* Phase 4 acceptance checks. Run after both Silver procedures complete.
   Counts show what is preserved, accepted, and quarantined; they do not assume all rows must load. */
SET NOCOUNT ON;
SELECT EntityName, BronzeRows, SilverRows, BronzeRows-SilverRows AS RowsNotInSilver
FROM (
 SELECT 'Accounts' EntityName,(SELECT COUNT_BIG(*) FROM brz.Accounts) BronzeRows,(SELECT COUNT_BIG(*) FROM slv.Accounts) SilverRows UNION ALL
 SELECT 'Activities',(SELECT COUNT_BIG(*) FROM brz.Activities),(SELECT COUNT_BIG(*) FROM slv.Activities) UNION ALL
 SELECT 'Campaigns',(SELECT COUNT_BIG(*) FROM brz.Campaigns),(SELECT COUNT_BIG(*) FROM slv.Campaigns) UNION ALL
 SELECT 'Contacts',(SELECT COUNT_BIG(*) FROM brz.Contacts),(SELECT COUNT_BIG(*) FROM slv.Contacts) UNION ALL
 SELECT 'Date',(SELECT COUNT_BIG(*) FROM brz.[Date]),(SELECT COUNT_BIG(*) FROM slv.CalendarDate) UNION ALL
 SELECT 'Leads',(SELECT COUNT_BIG(*) FROM brz.Leads),(SELECT COUNT_BIG(*) FROM slv.Leads) UNION ALL
 SELECT 'Opportunities',(SELECT COUNT_BIG(*) FROM brz.Opportunities),(SELECT COUNT_BIG(*) FROM slv.Opportunities) UNION ALL
 SELECT 'OpportunityProducts',(SELECT COUNT_BIG(*) FROM brz.OpportunityProducts),(SELECT COUNT_BIG(*) FROM slv.OpportunityProducts) UNION ALL
 SELECT 'Products',(SELECT COUNT_BIG(*) FROM brz.Products),(SELECT COUNT_BIG(*) FROM slv.Products) UNION ALL
 SELECT 'SalesReps',(SELECT COUNT_BIG(*) FROM brz.SalesReps),(SELECT COUNT_BIG(*) FROM slv.SalesReps) UNION ALL
 SELECT 'Targets',(SELECT COUNT_BIG(*) FROM brz.Targets),(SELECT COUNT_BIG(*) FROM slv.Targets)
) c ORDER BY EntityName;

SELECT EntityName,RuleCode,Severity,COUNT_BIG(*) AS ExceptionRows
FROM ctl.DataQualityException WHERE ExceptionStatus='OPEN'
GROUP BY EntityName,RuleCode,Severity ORDER BY EntityName,RuleCode;

/* Referential integrity checks are reported instead of silently deleting orphaned facts. */
SELECT 'Contacts.AccountID -> Accounts.AccountID' CheckName,COUNT_BIG(*) OrphanRows FROM slv.Contacts c LEFT JOIN slv.Accounts a ON a.AccountID=c.AccountID WHERE c.AccountID IS NOT NULL AND a.AccountID IS NULL
UNION ALL SELECT 'Activities.AccountID -> Accounts.AccountID',COUNT_BIG(*) FROM slv.Activities c LEFT JOIN slv.Accounts a ON a.AccountID=c.AccountID WHERE c.AccountID IS NOT NULL AND a.AccountID IS NULL
UNION ALL SELECT 'Activities.OpportunityID -> Opportunities.OpportunityID',COUNT_BIG(*) FROM slv.Activities c LEFT JOIN slv.Opportunities o ON o.OpportunityID=c.OpportunityID WHERE c.OpportunityID IS NOT NULL AND o.OpportunityID IS NULL
UNION ALL SELECT 'Activities.SalesRepID -> SalesReps.SalesRepID',COUNT_BIG(*) FROM slv.Activities c LEFT JOIN slv.SalesReps r ON r.SalesRepID=c.SalesRepID WHERE c.SalesRepID IS NOT NULL AND r.SalesRepID IS NULL
UNION ALL SELECT 'Leads.AccountID -> Accounts.AccountID',COUNT_BIG(*) FROM slv.Leads c LEFT JOIN slv.Accounts a ON a.AccountID=c.AccountID WHERE c.AccountID IS NOT NULL AND a.AccountID IS NULL
UNION ALL SELECT 'Leads.SalesRepID -> SalesReps.SalesRepID',COUNT_BIG(*) FROM slv.Leads c LEFT JOIN slv.SalesReps r ON r.SalesRepID=c.SalesRepID WHERE c.SalesRepID IS NOT NULL AND r.SalesRepID IS NULL
UNION ALL SELECT 'OpportunityProducts.ProductID -> Products.ProductID',COUNT_BIG(*) FROM slv.OpportunityProducts l LEFT JOIN slv.Products p ON p.ProductID=l.ProductID WHERE p.ProductID IS NULL
UNION ALL SELECT 'OpportunityProducts.OpportunityID -> Opportunities.OpportunityID',COUNT_BIG(*) FROM slv.OpportunityProducts l LEFT JOIN slv.Opportunities o ON o.OpportunityID=l.OpportunityID WHERE o.OpportunityID IS NULL
UNION ALL SELECT 'Targets.SalesRepID -> SalesReps.SalesRepID',COUNT_BIG(*) FROM slv.Targets t LEFT JOIN slv.SalesReps r ON r.SalesRepID=t.SalesRepID WHERE r.SalesRepID IS NULL;

/* Re-run safety: after each procedure runs twice against the same Bronze batch, Silver counts should be stable.
   This query captures current counts; compare before/after in the execution evidence log. */
SELECT 'SilverRows' Metric, SUM(RowCount) TotalRows FROM (
 SELECT COUNT_BIG(*) RowCount FROM slv.Accounts UNION ALL SELECT COUNT_BIG(*) FROM slv.Activities UNION ALL SELECT COUNT_BIG(*) FROM slv.Campaigns UNION ALL SELECT COUNT_BIG(*) FROM slv.Contacts UNION ALL SELECT COUNT_BIG(*) FROM slv.CalendarDate UNION ALL SELECT COUNT_BIG(*) FROM slv.Leads UNION ALL SELECT COUNT_BIG(*) FROM slv.OpportunityProducts UNION ALL SELECT COUNT_BIG(*) FROM slv.Products UNION ALL SELECT COUNT_BIG(*) FROM slv.Opportunities UNION ALL SELECT COUNT_BIG(*) FROM slv.SalesReps UNION ALL SELECT COUNT_BIG(*) FROM slv.Targets
) x;

SELECT TargetYear,ReconciliationStatus,COUNT_BIG(*) AS RepCount,SUM(DifferenceAmount) AS AggregateDifferenceAED
FROM ctl.TargetReconciliation GROUP BY TargetYear,ReconciliationStatus ORDER BY TargetYear,ReconciliationStatus;
