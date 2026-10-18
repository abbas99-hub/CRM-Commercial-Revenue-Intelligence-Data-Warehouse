"""Governed AI-access prototype: allowlisted query intents only; no arbitrary SQL execution.

Usage:
  python src/ai_access/governed_query_demo.py --list
  python src/ai_access/governed_query_demo.py --intent open_pipeline --region "North" --limit 20
  python src/ai_access/governed_query_demo.py --intent target_achievement --month 2026-09

Requires pyodbc and WAREHOUSE_SQL_CONNECTION to execute. Without a connection it prints
an explain-only plan; it never connects to an LLM or generates SQL from free-form text.
"""
from __future__ import annotations
import argparse
import json
import os
import re
import sys

QUERIES = {
    "won_revenue": {
        "description": "Won revenue by month and sales representative; actual-close-month attribution.",
        "view": "rpt.ai_WonRevenueByMonth",
        "sql": "SELECT TOP (?) [Year],[Month],SalesRepresentative,Manager,Region,WonDeals,WonRevenueAED,AverageWonDealAED FROM rpt.ai_WonRevenueByMonth WHERE (? IS NULL OR Region = ?) AND (? IS NULL OR [Month] = ?) ORDER BY [Month] DESC, WonRevenueAED DESC",
        "params": lambda a: (a.limit, a.region, a.region, a.month, a.month),
    },
    "open_pipeline": {
        "description": "Eligible open opportunities, current age, expected-close date and past-due status.",
        "view": "rpt.ai_OpenPipeline",
        "sql": "SELECT TOP (?) OpportunityID,Customer,SalesRepresentative,Manager,Region,Stage,ForecastCategory,ExpectedCloseDate,OpenPipelineAED,ProbabilityPct,AgeInDays,IsPastExpectedCloseDate,DaysPastDue FROM rpt.ai_OpenPipeline WHERE (? IS NULL OR Region = ?) AND (? IS NULL OR ExpectedCloseDate >= ?) AND (? IS NULL OR ExpectedCloseDate < DATEADD(day,1,?)) ORDER BY OpenPipelineAED DESC",
        "params": lambda a: (a.limit, a.region, a.region, a.from_date, a.from_date, a.to_date, a.to_date),
    },
    "weighted_pipeline": {
        "description": "Probability-weighted value for eligible open opportunities.",
        "view": "rpt.ai_WeightedPipeline",
        "sql": "SELECT TOP (?) OpportunityID,Customer,SalesRepresentative,Region,ExpectedCloseDate,OpenPipelineAED,ProbabilityPct,WeightedPipelineAED FROM rpt.ai_WeightedPipeline WHERE (? IS NULL OR Region = ?) ORDER BY WeightedPipelineAED DESC",
        "params": lambda a: (a.limit, a.region, a.region),
    },
    "win_rate": {
        "description": "Closed outcome win rate grouped by actual close month.",
        "view": "rpt.ai_WinRateByMonth",
        "sql": "SELECT TOP (?) [Year],[Month],SalesRepresentative,Manager,Region,WonDeals,LostDeals,ClosedDeals,WinRatePct FROM rpt.ai_WinRateByMonth WHERE (? IS NULL OR Region = ?) AND (? IS NULL OR [Month] = ?) ORDER BY [Month] DESC, WinRatePct DESC",
        "params": lambda a: (a.limit, a.region, a.region, a.month, a.month),
    },
    "target_achievement": {
        "description": "Monthly actual won revenue versus revenue target by representative.",
        "view": "rpt.ai_TargetAchievementByMonth",
        "sql": "SELECT TOP (?) [Year],[Month],SalesRepresentative,Manager,Region,RevenueTargetAED,WonRevenueAED,TargetAchievementPct,TargetStatus FROM rpt.ai_TargetAchievementByMonth WHERE (? IS NULL OR Region = ?) AND (? IS NULL OR [Month] = ?) ORDER BY [Month] DESC, TargetAchievementPct DESC",
        "params": lambda a: (a.limit, a.region, a.region, a.month, a.month),
    },
    "ageing": {
        "description": "Current ageing bands and overdue days for eligible open opportunities.",
        "view": "rpt.ai_OpportunityAgeing",
        "sql": "SELECT TOP (?) OpportunityID,Customer,SalesRepresentative,Manager,Region,Stage,EstimatedRevenueAED,AgeInDays,IsPastExpectedCloseDate,DaysPastDue,AgeingBand FROM rpt.ai_OpportunityAgeing WHERE (? IS NULL OR Region = ?) ORDER BY DaysPastDue DESC, EstimatedRevenueAED DESC",
        "params": lambda a: (a.limit, a.region, a.region),
    },
    "lead_conversion": {
        "description": "Lead conversion by created-month cohort; not conversion-month attribution.",
        "view": "rpt.ai_LeadConversionByMonth",
        "sql": "SELECT TOP (?) [Year],[Month],SalesRepresentative,Manager,Region,LeadsCreated,LeadsConverted,LeadConversionPct FROM rpt.ai_LeadConversionByMonth WHERE (? IS NULL OR Region = ?) AND (? IS NULL OR [Month] = ?) ORDER BY [Month] DESC, LeadConversionPct DESC",
        "params": lambda a: (a.limit, a.region, a.region, a.month, a.month),
    },
}

def valid_month(value: str | None) -> str | None:
    if value is None: return None
    if not re.fullmatch(r"\d{4}-(0[1-9]|1[0-2])", value):
        raise argparse.ArgumentTypeError("month must use YYYY-MM")
    return value

def valid_date(value: str | None) -> str | None:
    if value is None: return None
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
        raise argparse.ArgumentTypeError("date must use YYYY-MM-DD")
    return value

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--list", action="store_true", help="list approved intents")
    parser.add_argument("--intent", choices=sorted(QUERIES))
    parser.add_argument("--region")
    parser.add_argument("--month", type=valid_month)
    parser.add_argument("--from-date", type=valid_date)
    parser.add_argument("--to-date", type=valid_date)
    parser.add_argument("--limit", type=int, default=50)
    args = parser.parse_args()
    if args.limit < 1 or args.limit > 500:
        parser.error("limit must be between 1 and 500")
    if args.from_date and args.to_date and args.from_date > args.to_date:
        parser.error("from-date must be <= to-date")
    if args.list:
        print(json.dumps({k: {"view": v["view"], "description": v["description"]} for k,v in QUERIES.items()}, indent=2))
        return 0
    if not args.intent:
        parser.error("provide --intent or --list")
    spec = QUERIES[args.intent]
    print("Governed intent:", args.intent)
    print("Description:", spec["description"])
    print("Approved view:", spec["view"])
    print("Parameterized SQL:", spec["sql"])
    if not os.getenv("WAREHOUSE_SQL_CONNECTION"):
        print("Mode: EXPLAIN ONLY (WAREHOUSE_SQL_CONNECTION not set); no query executed.")
        return 0
    try:
        import pyodbc  # optional runtime dependency
    except ImportError:
        print("pyodbc is required to execute. Install with: pip install pyodbc", file=sys.stderr)
        return 2
    try:
        with pyodbc.connect(os.environ["WAREHOUSE_SQL_CONNECTION"], timeout=10) as conn:
            cur = conn.cursor()
            cur.execute(spec["sql"], spec["params"](args))
            columns = [c[0] for c in cur.description]
            rows = [dict(zip(columns, row)) for row in cur.fetchall()]
            print(json.dumps(rows, default=str, indent=2))
    except Exception as exc:  # report DB error; do not print connection string
        print(f"Query failed: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
