# Phase 4 test plan

| Test | Expected result | Status |
|---|---|---|
| Bronze physical counts preserved | No Bronze deletes or truncates from Silver transform | Script review only; SQL execution pending |
| Duplicate OpportunityID handling | Every row for each repeated key receives `OPP_DUPLICATE_CONFLICT`; none enters Silver | Script review only; SQL execution pending |
| Invalid date/decimal handling | Nonblank values that fail TRY_CONVERT are quarantined | Script review only; SQL execution pending |
| Opportunity probability bounds | Only 0–100 accepted | Script review only; SQL execution pending |
| Target month + rep uniqueness | All rows at duplicate grain are excluded and logged | Script review only; SQL execution pending |
| Annual/monthly target reconciliation | Full years compare; partial years are marked not comparable | Script review only; SQL execution pending |
| Source/Silver count reconciliation | Accepted + excluded row counts explain source count | Run SQL checks and save outputs |
| AED assumption | Currency labels are AED; source currency validation remains a documented business sign-off | Awaiting data-owner confirmation |
