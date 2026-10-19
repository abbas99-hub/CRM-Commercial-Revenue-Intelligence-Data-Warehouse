# Phase 1 — Business Requirements and KPI Definitions

## Project goal
Build a SQL-based commercial revenue data warehouse from CRM CSV sources, with Bronze/Silver/Gold layers and a governed Gold layer suitable for SQL analytics, Power BI, and future AI-assisted natural-language querying.

## Primary stakeholders
- Commercial director / sales leadership: revenue attainment, forecast confidence, pipeline risk, customer concentration.
- Sales managers: rep performance, ageing opportunities, activity coverage, next actions.
- Commercial analyst: consistent KPIs, reconciliation, segmentation, and exception reporting.
- Data/BI engineering: repeatable ingestion, data lineage, quality checks, model grain, and secure access.

## Business questions
1. What is won revenue by month, team, region, segment, industry, customer, and product?
2. What is the open pipeline and probability-weighted pipeline by expected close period?
3. How much of the target is achieved, what remains, and what is pipeline coverage?
4. What are win rate and average won deal size, with the denominator and closed-status logic documented?
5. Which opportunities are ageing, have missing expected close dates, or have high value but low probability?
6. Which reps and managers show differences in conversion, deal size, pipeline, and activity outcomes?
7. Which customers and products contribute most to revenue and gross-margin proxy?
8. What share of CRM records fails required-field, key, status, or referential-integrity checks?
9. How much does forecast composition depend on a small number of opportunities or customer accounts?
10. Can an AI assistant answer these questions using approved SQL views and the same definitions as BI?

## KPI glossary — draft definitions requiring validation
| KPI | Draft definition | Important caveat |
|---|---|---|
| Won Revenue | Sum of EstimatedRevenue for unique opportunities with Stage = Closed Won; compare to line revenue before selecting authoritative revenue source | Opportunity duplicates must be resolved first; EstimatedRevenue may differ from product-line revenue.
| Open Pipeline | Sum of EstimatedRevenue for opportunities in approved open stages | Exclude Closed Won/Closed Lost; define treatment for Unknown stage.
| Weighted Pipeline | Sum of EstimatedRevenue × ProbabilityPct / 100 for approved open opportunities | Probability quality and stage mapping need validation; not a guaranteed forecast.
| Win Rate | Closed Won count / (Closed Won count + Closed Lost count) | Use distinct, resolved OpportunityID and state the period basis.
| Average Deal Size | Won revenue / count of unique Closed Won opportunities | Must use same population and authoritative revenue definition.
| Target Achievement | Won revenue / RevenueTarget for same period and rep/team scope | Define actual-close-date attribution and target aggregation.
| Pipeline Coverage | Eligible open pipeline / remaining revenue target gap, or full-period target, depending on agreed policy | Do not mix the two definitions; publish the chosen definition.
| Opportunity Age | As-of date minus CreatedDate for open opportunities | Consider sales-cycle differences by segment/product.
| Close-date slippage | Expected close date versus a prior snapshot or actual close date | Current-state CSV may not contain historical snapshots, so true slippage needs history.
| Activity Intensity | Count of relevant activities per opportunity/rep over a defined period | Association is not causation; avoid ranking reps on activity volume alone.
| Gross Margin Proxy | Sum(LineRevenue - EstimatedCost) / sum(LineRevenue) | Use opportunity-product data; confirm whether line amounts reflect won business or pipeline estimates.
| Data Completeness | Records passing defined required-field checks / records in scope | Publish rule-level failures, not only one opaque score.
