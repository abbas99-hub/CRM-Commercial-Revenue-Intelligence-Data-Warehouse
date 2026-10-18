"""Offline Phase 4 source validation; does not require SQL Server.
Run: python src/validation/validate_phase4_sources.py --source-dir /path/to/CRM_Data
Validates source file headers, row counts, duplicate keys, expected date/numeric constraints and known issue counts.
"""
import argparse, csv, json
from collections import Counter, defaultdict
from datetime import datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path

EXPECTED = {
 'Accounts.csv': ['AccountID','AccountName','Industry','Country','City','Segment','TerritoryID','AnnualRevenue','Employees','AccountStatus'],
 'Activities.csv': ['ActivityID','OpportunityID','AccountID','SalesRepID','ActivityDate','ActivityType','Outcome','DurationMinutes'],
 'Campaigns.csv': ['CampaignID','CampaignName','CampaignType','StartDate','Budget','TargetSegment'],
 'Contacts.csv': ['ContactID','AccountID','ContactName','JobTitle','EmailOptIn'],
 'Date.csv': ['Date','Year','MonthNumber','Month','YearMonth','Quarter','WeekNumber','IsMonthEnd'],
 'Leads.csv': ['LeadID','CreatedDate','AccountID','LeadSource','Industry','LeadScore','Status','ConvertedDate','SalesRepID'],
 'Opportunities.csv': ['OpportunityID','AccountID','SalesRepID','CreatedDate','ExpectedCloseDate','ActualCloseDate','Stage','EstimatedRevenue','ProbabilityPct','LeadSource','Industry','Segment','CampaignID','ForecastCategory','CompetitorInvolved'],
 'OpportunityProducts.csv': ['OpportunityID','ProductID','Quantity','DiscountPct','LineRevenue','EstimatedCost'],
 'Products.csv': ['ProductID','ProductName','Category','UnitPrice','StandardMarginPct','Active'],
 'SalesReps.csv': ['SalesRepID','SalesRepName','ManagerName','TerritoryID','Region','TargetAnnual'],
 'Targets.csv': ['Month','SalesRepID','RevenueTarget','PipelineTarget','WinRateTargetPct'],
}
KEYS = {'Accounts.csv':'AccountID','Activities.csv':'ActivityID','Campaigns.csv':'CampaignID','Contacts.csv':'ContactID','Date.csv':'Date','Leads.csv':'LeadID','Opportunities.csv':'OpportunityID','Products.csv':'ProductID','SalesReps.csv':'SalesRepID'}
def read(path):
 with path.open('r',encoding='utf-8-sig',newline='') as f:
  r=csv.DictReader(f); rows=list(r); return r.fieldnames or [], rows
def malformed_width_count(path, expected_width):
 bad=0
 with path.open('r',encoding='utf-8-sig',newline='') as f:
  r=csv.reader(f); next(r, None)
  for row in r:
   if len(row)!=expected_width: bad+=1
 return bad
def dec(v):
 if v is None or not v.strip(): return None
 try: return Decimal(v.strip())
 except InvalidOperation: return 'INVALID'
def dt(v):
 if not v or not v.strip(): return None
 for fmt in ('%Y-%m-%d','%m/%d/%Y','%Y-%m-%d %H:%M:%S'):
  try:return datetime.strptime(v.strip(),fmt).date()
  except ValueError:pass
 return 'INVALID'
def main():
 ap=argparse.ArgumentParser(); ap.add_argument('--source-dir',required=True); ap.add_argument('--out',default='profiling/phase4_offline_validation.json'); a=ap.parse_args(); root=Path(a.source_dir)
 results={'source_dir':str(root),'files':{},'checks':[],'overall':'PASS'}
 for fn, expected in EXPECTED.items():
  path=root/fn
  if not path.exists(): results['overall']='FAIL'; results['files'][fn]={'status':'MISSING'}; continue
  header,rows=read(path); issues=[]
  if header!=expected: issues.append({'type':'HEADER_MISMATCH','expected':expected,'actual':header})
  width_errors=malformed_width_count(path,len(expected))
  if width_errors: issues.append({'type':'ROW_WIDTH_MISMATCH','count':width_errors})
  info={'status':'PASS' if not issues else 'FAIL','rows':len(rows),'columns':len(header),'malformed_row_width_count':width_errors,'issues':issues}
  if fn in KEYS:
   key=KEYS[fn]; counts=Counter((r.get(key) or '').strip() for r in rows); info['blank_keys']=counts.get('',0); info['duplicate_key_values']=sum(1 for k,v in counts.items() if k and v>1); info['rows_in_duplicate_key_groups']=sum(v for k,v in counts.items() if k and v>1)
  results['files'][fn]=info
  if issues: results['overall']='FAIL'
 # Type/domain checks mirror Silver acceptance rules without changing any source values.
 NUMERIC = {
  'Accounts.csv': {'AnnualRevenue':('decimal',0,None),'Employees':('int',0,None)},
  'Activities.csv': {'DurationMinutes':('int',0,None)},
  'Campaigns.csv': {'Budget':('decimal',0,None)},
  'Date.csv': {'Year':('int',1900,2200),'MonthNumber':('int',1,12),'WeekNumber':('int',1,53)},
  'Leads.csv': {'LeadScore':('decimal',0,100)},
  'Opportunities.csv': {'EstimatedRevenue':('decimal',0,None),'ProbabilityPct':('decimal',0,100)},
  'OpportunityProducts.csv': {'Quantity':('decimal',0,None),'DiscountPct':('decimal',0,100),'LineRevenue':('decimal',0,None),'EstimatedCost':('decimal',0,None)},
  'Products.csv': {'UnitPrice':('decimal',0,None),'StandardMarginPct':('decimal',0,100)},
  'SalesReps.csv': {'TargetAnnual':('decimal',0,None)},
  'Targets.csv': {'RevenueTarget':('decimal',0,None),'PipelineTarget':('decimal',0,None),'WinRateTargetPct':('decimal',0,100)},
 }
 DATE_FIELDS={'Activities.csv':['ActivityDate'],'Campaigns.csv':['StartDate'],'Date.csv':['Date'],'Leads.csv':['CreatedDate','ConvertedDate'],'Opportunities.csv':['CreatedDate','ExpectedCloseDate','ActualCloseDate'],'Targets.csv':['Month']}
 BOOL_FIELDS={'Contacts.csv':['EmailOptIn'],'Date.csv':['IsMonthEnd'],'Opportunities.csv':['CompetitorInvolved'],'Products.csv':['Active']}
 BOOLS={'1','0','TRUE','FALSE','YES','NO','Y','N'}
 for fn in EXPECTED:
  path=root/fn
  if not path.exists(): continue
  _, rows=read(path); issues=[]
  for col,(kind,lo,hi) in NUMERIC.get(fn,{}).items():
   invalid=0
   for r in rows:
    raw=(r.get(col) or '').strip()
    if not raw: continue
    try: value=int(raw) if kind=='int' else Decimal(raw)
    except (ValueError,InvalidOperation): invalid+=1; continue
    if (lo is not None and value<lo) or (hi is not None and value>hi): invalid+=1
   if invalid: issues.append({'type':'NUMERIC_DOMAIN_INVALID','column':col,'count':invalid})
  for col in DATE_FIELDS.get(fn,[]):
   invalid=sum(1 for r in rows if (r.get(col) or '').strip() and dt(r[col])=='INVALID')
   if invalid: issues.append({'type':'DATE_INVALID','column':col,'count':invalid})
  for col in BOOL_FIELDS.get(fn,[]):
   invalid=sum(1 for r in rows if (r.get(col) or '').strip() and r[col].strip().upper() not in BOOLS)
   if invalid: issues.append({'type':'BOOLEAN_INVALID','column':col,'count':invalid})
  if fn=='Leads.csv':
   invalid=sum(1 for r in rows if (r.get('Status') or '').strip().upper() not in {'OPEN','CONVERTED','NURTURE','DISQUALIFIED'} or ((r.get('Status') or '').strip().upper()=='CONVERTED' and dt(r.get('ConvertedDate','')) in (None,'INVALID')) or ((r.get('Status') or '').strip().upper()!='CONVERTED' and (r.get('ConvertedDate') or '').strip()))
   if invalid: issues.append({'type':'LEAD_STATUS_DATE_RULE_INVALID','count':invalid})
  if issues:
   results['overall']='FAIL'
   results['files'][fn]['status']='FAIL'
   results['files'][fn]['issues'].extend(issues)
  results['files'][fn]['type_domain_checks']='PASS' if not issues else 'FAIL'
 # Known anomaly assertions, only report actual counts rather than silently assuming.
 results['total_source_rows']=sum(v.get('rows',0) for v in results['files'].values())
 results['expected_total_source_rows']=93837
 results['checks'].append({'check':'total_source_row_count','actual':results['total_source_rows'],'expected':93837,'pass':results['total_source_rows']==93837})
 op=results['files'].get('Opportunities.csv',{}); results['checks'].append({'check':'opportunity_duplicate_key_groups','actual':op.get('duplicate_key_values'),'expected_profile':35,'pass':op.get('duplicate_key_values')==35})
 prod_path=root/'OpportunityProducts.csv'
 if prod_path.exists():
  _,rows=read(prod_path); pairs=Counter(((r.get('OpportunityID') or '').strip(),(r.get('ProductID') or '').strip()) for r in rows); rep=sum(1 for k,v in pairs.items() if k[0] and k[1] and v>1); rows_rep=sum(v for k,v in pairs.items() if k[0] and k[1] and v>1)
  results['checks'].append({'check':'repeated_opportunity_product_pairs','actual_pairs':rep,'rows_in_repeated_pairs':rows_rep,'expected_profile_pairs':203,'expected_profile_rows':406,'pass':rep==203 and rows_rep==406})
 # Target grain uniqueness
 tp=root/'Targets.csv'
 if tp.exists():
  _,rows=read(tp); pairs=Counter(((r.get('Month') or '').strip(),(r.get('SalesRepID') or '').strip()) for r in rows); dups=sum(1 for k,v in pairs.items() if k[0] and k[1] and v>1)
  results['checks'].append({'check':'target_month_rep_grain_duplicates','actual_duplicate_grains':dups,'pass':dups==0})
 if any(not x['pass'] for x in results['checks']): results['overall']='FAIL'
 out=Path(a.out); out.parent.mkdir(parents=True,exist_ok=True); out.write_text(json.dumps(results,indent=2),encoding='utf-8')
 print(json.dumps(results,indent=2)); print(f'Wrote {out}')
 if results['overall']!='PASS': raise SystemExit(1)
if __name__=='__main__': main()
