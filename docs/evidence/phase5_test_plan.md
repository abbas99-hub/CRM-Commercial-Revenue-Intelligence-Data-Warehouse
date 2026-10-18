# Phase 5 Gold test plan

Run in SQL Server after Phase 4 is successfully loaded.

1. Execute Gold DDL and confirm all tables/FKs exist.
2. Execute `gld.usp_LoadGold` twice against the same Silver snapshot; both runs should complete and produce identical counts/measures. Identity surrogate values may be recreated by design.
3. Run relationship/aggregation checks. All orphan counts must be zero.
4. Verify dimension business keys are unique and fact grains match the definitions in `phase5_gold_model.md`.
5. Compare each Silver fact-source count to its Gold fact count. Opportunity facts should equal eligible resolved Silver opportunities; other facts should match their Silver rows subject to FK-safe unknown mappings.
6. Compare `SUM(slv.Opportunities.EstimatedRevenue)` for Closed Won with `SUM(gld.FactOpportunity.WonRevenueAED)`. Values must match.
7. Compare opportunity product line revenue to won estimated revenue and document the variance; they are different measures and are not expected to match automatically.
8. Record the count of rows assigned to Unknown dimensions.
9. Review `IsTrustedForPipeline`, Unknown stages, and missing revenue/probability before using pipeline measures.

The scripts are not claimed to have run against SQL Server in this environment. Capture actual result sets as acceptance evidence.
