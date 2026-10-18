# Phase 5 — Gold dimensional model

## Scope and grain

| Object | Grain | Primary business purpose |
|---|---|---|
| `gld.DimCustomer` | One row per `AccountID` | Customer/segment/industry analysis |
| `gld.DimProduct` | One row per `ProductID` | Product/category analysis |
| `gld.DimSalesRep` | One row per `SalesRepID` | Rep, manager, region and target analysis |
| `gld.DimCampaign` | One row per `CampaignID` | Campaign performance attributes |
| `gld.DimContact` | One row per `ContactID` | Contact attributes; account is a descriptive business key |
| `gld.DimDate` | One row per calendar date plus key 0 Unknown | Role-playing date dimension |
| `gld.FactOpportunity` | One row per resolved `OpportunityID` | Pipeline, weighted pipeline and won revenue |
| `gld.FactActivity` | One row per `ActivityID` | Activity counts and duration |
| `gld.FactOpportunityProduct` | One physical Silver source line | Product-line revenue/cost analysis |
| `gld.FactLead` | One row per `LeadID` | Lead funnel and conversion analysis |
| `gld.FactSalesTarget` | One sales representative per target month | Monthly target achievement |

## Relationships

All dimension-to-fact joins are one-to-many. Facts use surrogate keys for customer, product, sales rep, campaign and date. Unknown/missing dimension lookups use key `0`, not an orphan key. Product lines whose opportunity is absent from the accepted Silver opportunity table have `IsOpportunityResolved = 0` and must be excluded from opportunity-attributed analysis until resolved. Date roles are separate FK columns into `DimDate`. There are deliberately no direct fact-to-fact foreign keys; `OpportunityID` in activity/product facts is a degenerate identifier, not a join to a fact table.

## Important measure semantics

- `WonRevenueAED` is derived only from `Stage = 'Closed Won'` and uses `EstimatedRevenue`, per the approved business decision.
- `WeightedPipelineAED` is a derived probability-weighted estimate for approved open stages only. Unknown stages are not treated as pipeline.
- `IsTrustedForPipeline` flags whether stage, revenue and probability pass basic trust criteria.
- `FactOpportunityProduct.LineRevenueAED` is not the authoritative won revenue measure; its total is compared with opportunity `EstimatedRevenue` for reconciliation only.
- Gross margin is not presented as authoritative until line revenue and estimated cost definitions are confirmed.
- All monetary fields are named AED per project requirements, but source currency is not independently verified. This remains a source-owner validation assumption.
- Forecast accuracy / close-date slippage cannot be reconstructed from current-state opportunities without snapshots or change history.

## Refresh strategy

`gld.usp_LoadGold` is a transactional full refresh for a fixed Silver snapshot. It deletes facts before dimensions and reloads all Gold objects. It is idempotent for the same Silver snapshot but is not an incremental/SCD implementation; do not run concurrently with reporting. Production incremental loading would require stable dimension key maintenance and a defined SCD policy.

## Execution order

1. Ensure Phase 4 Silver objects exist and transformations have completed.
2. Run `sql/03_gold/100_create_gold_tables.sql`.
3. Run `sql/03_gold/110_load_gold.sql`.
4. Execute `EXEC gld.usp_LoadGold;`.
5. Run `sql/03_gold/200_gold_relationship_and_aggregation_checks.sql`.
6. Save the result sets and compare Silver/Gold record counts and won revenue.

## Acceptance criteria

- Each dimension business key is unique (excluding the single Unknown member).
- Each fact is unique at its stated grain.
- FK constraints create only valid one-to-many dimension relationships.
- Silver-to-Gold fact row counts reconcile exactly for eligible Silver rows.
- Silver won revenue equals Gold won revenue to the database decimal precision.
- Unknown-member usage is quantified and explained.
- Opportunity product-line total is reconciled separately and is not substituted for won revenue.

**Execution status:** SQL scripts are authored; live SQL Server execution and acceptance evidence are still required.
