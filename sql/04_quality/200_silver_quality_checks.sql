/* Run after slv.usp_TransformOpportunitiesAndTargets. These checks report; they do not repair source data. */
SET NOCOUNT ON;
SELECT 'Opportunities_Bronze' AS Metric, COUNT_BIG(*) AS RowCount FROM brz.Opportunities
UNION ALL SELECT 'Opportunities_Silver', COUNT_BIG(*) FROM slv.Opportunities
UNION ALL SELECT 'Opportunity_Exception_Rows', COUNT_BIG(*) FROM ctl.DataQualityException WHERE EntityName='Opportunities' AND ExceptionStatus='OPEN';
SELECT RuleCode, Severity, COUNT_BIG(*) AS ExceptionCount
FROM ctl.DataQualityException WHERE ExceptionStatus='OPEN'
GROUP BY RuleCode,Severity ORDER BY Severity,RuleCode;
SELECT TargetYear, ReconciliationStatus, COUNT_BIG(*) AS RepCount,
       SUM(DifferenceAmount) AS AggregateDifferenceAED
FROM ctl.TargetReconciliation GROUP BY TargetYear,ReconciliationStatus ORDER BY TargetYear,ReconciliationStatus;
SELECT COUNT_BIG(*) AS InvalidCurrencyRows FROM slv.Opportunities WHERE RevenueCurrency<>'AED'
UNION ALL SELECT COUNT_BIG(*) FROM slv.SalesReps WHERE TargetCurrency<>'AED'
UNION ALL SELECT COUNT_BIG(*) FROM slv.Targets WHERE TargetCurrency<>'AED';
