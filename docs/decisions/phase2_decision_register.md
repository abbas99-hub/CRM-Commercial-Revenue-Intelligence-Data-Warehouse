# Phase 2 Decision Register

Status key: **Approved design** = chosen for this portfolio build; **Pending validation** = must be confirmed against source/business owner before production claims.

| ID | Topic | Decision | Status / control |
|---|---|---|---|
| DQ-001 | Conflicting duplicate OpportunityID | Preserve all source rows in Bronze; identify every conflicting key; quarantine all records for affected IDs from trusted opportunity facts until a documented authoritative resolution. Never pick a row arbitrarily. | Approved design |
| DQ-002 | Opportunity-product repeated pairs | Pair is not a key. Add warehouse-generated OpportunityProductLineKey plus source file, source row and batch metadata. Preserve every line; investigate whether repeats are valid. | Approved design |
| REV-001 | Won revenue | SUM(EstimatedRevenue) for resolved, unique Closed Won opportunities passing quality gates. Product LineRevenue is reconciliation-only until semantics are confirmed. | Approved design |
| REV-002 | Gross margin | Do not publish as authoritative until LineRevenue and EstimatedCost grain/meaning and reconciliation to opportunity revenue are confirmed. | Pending validation |
| FC-001 | Stage vs forecast category | Stage controls open/closed status. ForecastCategory is a separate classification for eligible open opportunities. Unknown stages and invalid combinations are quality exceptions; do not silently rewrite source values. | Approved design |
| TGT-001 | Annual vs monthly target | Monthly Targets at SalesRepID × Month is the detailed target grain. Recalculate annual revenue target as the sum of 12 monthly targets and compare with SalesReps.TargetAnnual. Report differences; do not force values to match. Partial years must be labelled YTD. | Approved design |
| CUR-001 | Currency | Standardize reporting contract and monetary column names to AED. Source currency is not supplied, so AED equivalence is an explicit assumption pending source-owner confirmation. Do not apply FX conversion without source currency/rates. | Pending validation |
| HIS-001 | Historical forecast accuracy | Current-state opportunity rows do not establish historical state. Do not claim historical forecast accuracy or close-date slippage. Add periodic snapshots/change events prospectively. | Approved design |
| KEY-001 | Surrogate keys | Use warehouse surrogate keys in Gold dimensions/facts; retain source business keys for traceability. | Approved design |
| AUD-001 | Lineage | Retain source filename, source row number where available, batch ID, ingestion timestamp, record hash, and rule outcomes across layers. | Approved design |
