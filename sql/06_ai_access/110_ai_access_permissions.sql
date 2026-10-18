/* Least-privilege template. Run as database administrator and adapt principal names.
   Create the role once; create/login/user mapping is environment-specific.
*/
IF DATABASE_PRINCIPAL_ID(N'CommercialAIAccessReader') IS NULL
    CREATE ROLE CommercialAIAccessReader AUTHORIZATION dbo;
GO
GRANT SELECT ON OBJECT::rpt.ai_WonRevenueByMonth TO CommercialAIAccessReader;
GRANT SELECT ON OBJECT::rpt.ai_OpenPipeline TO CommercialAIAccessReader;
GRANT SELECT ON OBJECT::rpt.ai_WeightedPipeline TO CommercialAIAccessReader;
GRANT SELECT ON OBJECT::rpt.ai_WinRateByMonth TO CommercialAIAccessReader;
GRANT SELECT ON OBJECT::rpt.ai_TargetAchievementByMonth TO CommercialAIAccessReader;
GRANT SELECT ON OBJECT::rpt.ai_OpportunityAgeing TO CommercialAIAccessReader;
GRANT SELECT ON OBJECT::rpt.ai_LeadConversionByMonth TO CommercialAIAccessReader;
GRANT SELECT ON OBJECT::rpt.ai_SalesActivityByMonth TO CommercialAIAccessReader;
GRANT SELECT ON OBJECT::rpt.ai_ProductLineMargin TO CommercialAIAccessReader;
GO
/* Do not grant db_datareader or direct SELECT on gld/slv/brz to the AI identity. */
