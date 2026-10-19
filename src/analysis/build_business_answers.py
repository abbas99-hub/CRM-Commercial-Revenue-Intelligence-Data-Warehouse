"""Build reproducible descriptive KPI answers from the provided CRM dataset.

Gold/rpt execution. It excludes all rows belonging to duplicated OpportunityIDs.
Usage: python src/analysis/build_business_answers.py --data-dir data/sample --out-dir docs/evidence
"""
import argparse, json
from pathlib import Path
import pandas as pd

OPEN_STAGES = {"Qualification", "Needs Analysis", "Proposal", "Negotiation"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--data-dir', default='data/sample')
    ap.add_argument('--out-dir', default='docs/evidence')
    ap.add_argument('--as-of', default='2026-10-17', help='Reference date for current-state ageing/overdue metrics')
    args = ap.parse_args()
    d, out = Path(args.data_dir), Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    opp = pd.read_csv(d/'Opportunities.csv', parse_dates=['CreatedDate','ExpectedCloseDate','ActualCloseDate'])
    dup_ids = opp.loc[opp.duplicated('OpportunityID', keep=False), 'OpportunityID'].unique()
    trusted = opp.loc[~opp['OpportunityID'].isin(dup_ids)].copy()
    # Stage semantics are explicit; Unknown is not treated as open or closed.
    won = trusted[(trusted.Stage == 'Closed Won') & trusted.ActualCloseDate.notna()].copy()
    lost = trusted[(trusted.Stage == 'Closed Lost') & trusted.ActualCloseDate.notna()].copy()
    won['Year'] = won.ActualCloseDate.dt.year
    lost['Year'] = lost.ActualCloseDate.dt.year
    year_rows=[]
    for year in sorted(set(won.Year.dropna().astype(int)) | set(lost.Year.dropna().astype(int))):
        wy, ly = won[won.Year == year], lost[lost.Year == year]
        year_rows.append({'Metric':'Closed outcome performance','Period':str(year),'WonDeals':int(len(wy)),
                          'LostDeals':int(len(ly)),'WinRatePct':round(100*len(wy)/(len(wy)+len(ly)),2) if len(wy)+len(ly) else None,
                          'WonRevenueAED':round(float(wy.EstimatedRevenue.sum()),2),
                          'AverageWonDealAED':round(float(wy.EstimatedRevenue.mean()),2) if len(wy) else None,
                          'Notes':'Actual close year; conflicting duplicate opportunity IDs excluded; source currency unverified.'})
    opn = trusted[trusted.Stage.isin(OPEN_STAGES) & trusted.EstimatedRevenue.gt(0) & trusted.ProbabilityPct.between(0,100) & trusted.ProbabilityPct.notna()].copy()
    asof = pd.Timestamp(args.as_of)
    overdue = opn.ExpectedCloseDate.notna() & (opn.ExpectedCloseDate < asof)
    open_metrics = [
      {'Metric':'Eligible current open pipeline','Period':f'As of {args.as_of}','Value':round(float(opn.EstimatedRevenue.sum()),2),'Unit':'AED','Interpretation':'Sum of positive estimated revenue in approved open stages, valid probability, excluding duplicate IDs.'},
      {'Metric':'Probability-weighted open pipeline','Period':f'As of {args.as_of}','Value':round(float((opn.EstimatedRevenue*opn.ProbabilityPct/100).sum()),2),'Unit':'AED','Interpretation':'Estimated revenue × stored probability; not a calibrated or guaranteed forecast.'},
      {'Metric':'Open opportunities past expected close','Period':f'As of {args.as_of}','Value':int(overdue.sum()),'Unit':'opportunities','Interpretation':'Current-state date comparison; not historical close-date slippage.'},
      {'Metric':'Past-expected-close open pipeline value','Period':f'As of {args.as_of}','Value':round(float(opn.loc[overdue,'EstimatedRevenue'].sum()),2),'Unit':'AED','Interpretation':'Open pipeline whose expected close date precedes the reference date.'},
    ]
    leads = pd.read_csv(d/'Leads.csv')
    lead_count = len(leads); converted = int((leads.Status == 'Converted').sum())
    activities = pd.read_csv(d/'Activities.csv')
    targets = pd.read_csv(d/'Targets.csv', parse_dates=['Month'])
    # Target comparison is based on month of actual close and rep. Target table runs through Sep 2026.
    w = won.copy(); w['Month'] = w.ActualCloseDate.dt.to_period('M').dt.to_timestamp()
    rev = w.groupby(['Month','SalesRepID'], as_index=False).EstimatedRevenue.sum().rename(columns={'EstimatedRevenue':'WonRevenueAED'})
    target_perf = targets.merge(rev, on=['Month','SalesRepID'], how='left')
    target_perf['WonRevenueAED'] = target_perf['WonRevenueAED'].fillna(0)
    target_perf['Year'] = target_perf.Month.dt.year
    target_rows=[]
    for year, g in target_perf.groupby('Year'):
        target_rows.append({'Metric':'Target attainment across available target months','Period':str(int(year)),
          'WonRevenueAED':round(float(g.WonRevenueAED.sum()),2),'RevenueTargetAED':round(float(g.RevenueTarget.sum()),2),
          'TargetAchievementPct':round(100*float(g.WonRevenueAED.sum())/float(g.RevenueTarget.sum()),2) if g.RevenueTarget.sum() else None,
          'MonthsAvailable':int(g.Month.nunique()),'RepMonthRows':int(len(g)),
          'Notes':'2026 includes Jan-Sep only; actuals attributed to actual close month; conflicting duplicate IDs excluded.'})
    reps = pd.read_csv(d/'SalesReps.csv')
    industry = won.groupby('Industry', dropna=False).EstimatedRevenue.sum().sort_values(ascending=False).head(5)
    kpis = [
      {'Metric':'Source records','Period':'All supplied CSVs','Value':93837,'Unit':'rows','Interpretation':'11 core entity files; includes known duplicate opportunity records.'},
      {'Metric':'Opportunity rows quarantined','Period':'Source quality','Value':int(opp.OpportunityID.isin(dup_ids).sum()),'Unit':'rows','Interpretation':f'{len(dup_ids)} OpportunityID values have conflicting duplicate rows; all {int(opp.OpportunityID.isin(dup_ids).sum())} rows excluded from KPI calculations.'},
      {'Metric':'Eligible opportunity records after duplicate exclusion','Period':'Source quality','Value':int(len(trusted)),'Unit':'rows','Interpretation':'Remaining rows still include 25 Unknown-stage records; these are excluded from approved stage-based KPIs.'},
      {'Metric':'Leads converted by status','Period':'All supplied leads','Value':round(100*converted/lead_count,2) if lead_count else None,'Unit':'%','Interpretation':f'{converted:,} status=Converted out of {lead_count:,}; no lead-to-opportunity bridge is provided.'},
      {'Metric':'Activity records','Period':'All supplied activities','Value':int(len(activities)),'Unit':'activities','Interpretation':'Descriptive workload volume; does not establish causal sales effectiveness.'},
      {'Metric':'Activity duration','Period':'All supplied activities','Value':int(activities.DurationMinutes.sum()),'Unit':'minutes','Interpretation':'Sum of recorded duration minutes.'},
      {'Metric':'Provisional product-line gross margin','Period':'All product lines','Value':round(100*(pd.read_csv(d/'OpportunityProducts.csv').LineRevenue.sum()-pd.read_csv(d/'OpportunityProducts.csv').EstimatedCost.sum())/pd.read_csv(d/'OpportunityProducts.csv').LineRevenue.sum(),2),'Unit':'%','Interpretation':'Illustrative only; product-line semantics are unvalidated and this is not the authoritative won-revenue measure.'},
    ]
    kpi_df = pd.DataFrame(kpis + open_metrics)
    kpi_df.to_csv(out/'commercial_kpi_snapshot.csv', index=False)
    pd.DataFrame(year_rows).to_csv(out/'closed_outcome_performance_by_year.csv', index=False)
    pd.DataFrame(target_rows).to_csv(out/'target_attainment_by_year.csv', index=False)
    pd.DataFrame([{'Industry':idx,'WonRevenueAED':round(float(val),2)} for idx,val in industry.items()]).to_csv(out/'top_industries_by_won_revenue.csv', index=False)
    result = {'reference_date':args.as_of,'source_currency':'unverified; AED is project convention',
      'source_rows':93837,'opportunity_rows':int(len(opp)),'conflicting_duplicate_opportunity_ids':int(len(dup_ids)),
      'opportunity_rows_excluded':int(opp.OpportunityID.isin(dup_ids).sum()),'trusted_opportunity_rows':int(len(trusted)),
      'unknown_stage_rows_after_duplicate_exclusion':int((trusted.Stage=='Unknown').sum()),
      'eligible_open_opportunities':int(len(opn)),'eligible_open_pipeline_aed':round(float(opn.EstimatedRevenue.sum()),2),
      'weighted_open_pipeline_aed':round(float((opn.EstimatedRevenue*opn.ProbabilityPct/100).sum()),2),
      'overdue_open_opportunities':int(overdue.sum()),'overdue_open_pipeline_aed':round(float(opn.loc[overdue,'EstimatedRevenue'].sum()),2),
      'lead_count':int(lead_count),'converted_leads':converted,'lead_status_conversion_pct':round(100*converted/lead_count,2),
      'activity_count':int(len(activities)),'activity_duration_minutes':int(activities.DurationMinutes.sum()),
      'closed_outcome_by_year':year_rows,'target_attainment_by_year':target_rows,
      'top_industries_by_won_revenue':[{'industry':str(k),'won_revenue_aed':round(float(v),2)} for k,v in industry.items()],
      'runtime_status':'Source-level descriptive calculations only. SQL Server views, Gold loads, role restrictions, and AI adapter execution are not runtime-validated.'}
    (out/'commercial_kpi_snapshot.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    lines=['# Commercial KPI snapshot — source-level portfolio answers','',f'**Reference date:** {args.as_of}. **Currency:** values are labelled AED by project convention; source currency is not confirmed.','',
      '> These are reproducible descriptive calculations directly from the sample CSVs, with all rows belonging to 35 conflicting duplicate OpportunityID values excluded from opportunity-based KPIs. They are not SQL Server runtime results or real company performance.','',
      '## Quality and pipeline']
    lines += [f"- Source rows across the 11 core entities: **93,837**.",f"- Opportunity duplicate quarantine: **{len(dup_ids)} conflicting IDs / {int(opp.OpportunityID.isin(dup_ids).sum())} rows excluded**.",f"- Eligible open opportunities: **{len(opn):,}**; open pipeline: **AED {opn.EstimatedRevenue.sum():,.0f}**; probability-weighted pipeline: **AED {(opn.EstimatedRevenue*opn.ProbabilityPct/100).sum():,.0f}**.",f"- Past expected close as of {args.as_of}: **{int(overdue.sum()):,} opportunities**, representing **AED {opn.loc[overdue,'EstimatedRevenue'].sum():,.0f}** of pipeline. This is a current-state alert, not proof of historical slippage.",'', '## Closed outcomes by actual close year','', '| Year | Won deals | Lost deals | Win rate | Won revenue (AED, project convention) | Average won deal (AED) |','|---:|---:|---:|---:|---:|---:|']
    for r in year_rows: lines.append(f"| {r['Period']} | {r['WonDeals']:,} | {r['LostDeals']:,} | {r['WinRatePct']:.2f}% | {r['WonRevenueAED']:,.0f} | {r['AverageWonDealAED']:,.0f} |")
    lines += ['', '## Target attainment by target months available','', '| Year | Months | Won revenue (AED) | Revenue target (AED) | Achievement |','|---:|---:|---:|---:|---:|']
    for r in target_rows: lines.append(f"| {r['Period']} | {r['MonthsAvailable']} | {r['WonRevenueAED']:,.0f} | {r['RevenueTargetAED']:,.0f} | {r['TargetAchievementPct']:.2f}% |")
    lines += ['', '## Additional commercial indicators','',f"- Lead status conversion: **{converted:,}/{lead_count:,} = {100*converted/lead_count:.2f}%**. This is based on `Status = Converted`; there is no lead-to-opportunity bridge.",f"- Sales activity: **{len(activities):,} records** and **{int(activities.DurationMinutes.sum()):,} recorded minutes**. Activity volume is not proof of effectiveness.",'- Top industries by won revenue (actual close date; trusted opportunities only):']
    for idx,val in industry.items(): lines.append(f'  - {idx}: AED {val:,.0f}')
    lines += ['', '## Interpretation and limitations','', '- The sample data is synthetic/demo-style and should not be presented as actual company performance.', '- AED is a project reporting convention only; confirm source currency before business use.', '- 2026 target attainment includes January–September only because the target table ends in September 2026. Do not compare directly with a full-year target.', '- All 70 opportunity rows belonging to 35 conflicting duplicate IDs are excluded. The 25 remaining `Unknown` stage records are excluded from approved open/closed stage KPIs.', '- Weighted pipeline is a simple probability-weighted estimate, not a calibrated forecast.', '- SQL Server execution and permission tests remain pending; this report is a separate reproducible source-level cross-check.','']
    (out/'commercial_kpi_snapshot.md').write_text('\n'.join(lines), encoding='utf-8')
    print(f'Wrote KPI evidence to {out}; trusted opportunities={len(trusted)}, eligible open={len(opn)}')

if __name__ == '__main__': main()
