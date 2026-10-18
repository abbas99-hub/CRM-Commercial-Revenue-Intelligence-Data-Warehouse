# Building a Commercial Revenue Intelligence Warehouse: From Messy CRM Data to Governed AI-Ready KPIs

*Portfolio case study draft. The supplied dataset is synthetic/demo-style; this article describes the implementation and source-level analysis, not a production deployment.*

## The problem I wanted to solve

Commercial leaders often ask straightforward questions—what did we win, how healthy is the pipeline, who is behind target, and which deals need attention? The hard part is not writing one query. It is making sure different reports use the same definitions, duplicate records do not inflate totals, and an AI assistant cannot bypass access controls to query raw tables.

I built a SQL-first portfolio project to make those concerns explicit from ingestion through an AI-ready access layer.

## The dataset

The sample contains 11 core CSV entities and 93,837 rows across accounts, contacts, sales representatives, products, campaigns, leads, opportunities, opportunity-product lines, activities, dates and targets. It resembles a CRM export, but it is not a live Dynamics 365 integration and should not be interpreted as real company performance.

The first important finding was a data-quality problem: 35 OpportunityID values appeared in conflicting duplicate records, affecting 70 rows. Rather than choosing an arbitrary winner, I designed the flow to quarantine them until an authoritative record can be approved. I also found 203 repeated OpportunityID + ProductID pairs (406 rows), which I preserved because the source does not provide a stable product-line ID.

## Architecture

![Architecture](../images/architecture.svg)

The layers are:

1. **Bronze (`brz`)** — raw source values, ingestion batches and row-level lineage.
2. **Silver (`slv`)** — typed attributes, transformations, explicit quality checks and quarantine behavior.
3. **Gold (`gld`)** — dimensions for customer, product, sales representative, campaign, date and contact; facts for opportunity, activity, opportunity product, lead and sales target.
4. **Reporting (`rpt`)** — reusable commercial KPI views with documented grains and edge cases.
5. **AI access (`rpt.ai_*`)** — stable business-named views plus a constrained query adapter and least-privilege role template.

The architecture intentionally separates opportunity, activity and product-line facts to avoid fanout errors when measures are aggregated.

## KPI contracts

I documented each KPI with a formula, time attribution, exclusions and caveats. Examples:

- **Won revenue:** `EstimatedRevenue` for trusted Closed Won opportunities, assigned to actual close month.
- **Win rate:** Closed Won / (Closed Won + Closed Lost), calculated from counts at the selected reporting grain.
- **Open pipeline:** positive estimated revenue for approved open stages with a valid probability.
- **Weighted pipeline:** estimated revenue multiplied by stored probability. This is a simple weighting, not a calibrated forecast.
- **Lead conversion:** leads with status Converted divided by leads in the created cohort. The dataset does not include an explicit lead-to-opportunity bridge.
- **Product-line margin:** provisional line-level calculation; it is not treated as authoritative won revenue.

The source does not specify currency, so AED is used only as a reporting convention. A real implementation would require confirmation from the data owner.

## What the sample says

After excluding all 70 rows belonging to the 35 conflicting opportunity IDs, the source-level calculation finds:

- **10,128 eligible open opportunities**, representing approximately **AED 442.8 million** in open pipeline.
- Approximately **AED 182.3 million** in probability-weighted pipeline using the stored probability values.
- As of 17 October 2026, **10,010 open opportunities** have expected close dates before the reference date, representing approximately AED 437.6 million in pipeline. This is a current-state follow-up signal—not proof of historical close-date slippage.
- **1,394 of 5,000 leads** are marked Converted, or **27.88%** by status. This cannot be described as lead-to-revenue conversion.
- Target attainment for the available 2026 target months is **62.30% for January–September**. It is not a full-year comparison.

These are descriptive results calculated directly from the sample CSVs. They are not SQL Server runtime outputs and are not actual commercial performance. Reproducible CSV, JSON and Markdown outputs are included in `docs/evidence/`.

## AI-ready does not mean unrestricted text-to-SQL

The final layer exposes nine approved business-named views. The Python prototype maps a fixed set of intents to parameterized query templates, validates month/date inputs and caps result size. With no connection string configured, it only prints an explain-only plan. It does not accept raw SQL and does not call an LLM.

This is deliberate. A future natural-language layer should classify requests into approved intents, use a read-only identity, enforce row-level access where needed, log query activity, cap results and return the metric definition with each answer. A conversational interface should not be able to invent query shapes or access base tables by default.

## Validation: what is tested and what remains

Offline checks passed for the 11 source file contracts, 93,837 total rows, zero malformed row widths, detection of 35 conflicting duplicate opportunity IDs, detection of 203 repeated product pairs, and unique Month + SalesRepID target grain. Local Python tests and syntax checks are included for reproduction.

SQL Server execution is still a separate acceptance gate. DDL, transformation procedures, Gold loads, reporting views, KPI reconciliation and restricted-role permission denials must be executed and captured in a real SQL Server environment. I do not claim those runtime tests have passed. Likewise, an LLM-to-intent classifier is not included in this prototype.

## What I learned

1. Data quality decisions are part of business logic: silently deduplicating a revenue opportunity can materially distort the result.
2. KPI definitions need grain, date attribution and exclusion rules—not just a formula.
3. A star schema and separate fact grains protect the accuracy of aggregated metrics.
4. AI governance starts with approved data contracts and permissions. The query interface is the final layer, not the foundation.
5. Good portfolio evidence distinguishes offline validation, runtime validation and future work.

## Repository and next steps

The repository includes the SQL scripts, source data, diagrams, data dictionary, validation evidence, KPI glossary, query examples and implementation runbook. The next milestone is to run the complete sequence in a test SQL Server database, reconcile SQL outputs with the independent source-level baseline, and test that the AI reader can access approved views but not raw or base tables.

**Repository:** [add your GitHub repository URL]

**Disclaimer:** This is an educational portfolio project using synthetic/demo-style data. Monetary amounts are labelled AED by project convention pending source confirmation. No live CRM connection, production deployment or measured business impact is claimed.
