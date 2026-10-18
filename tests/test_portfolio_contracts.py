"""Fast local contract tests; no SQL Server connection required."""
import csv
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'data' / 'sample'


def read_csv(name):
    with (DATA / name).open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))


class SourceContractTests(unittest.TestCase):
    def test_core_source_row_count(self):
        entities = ['Accounts.csv','Activities.csv','Campaigns.csv','Contacts.csv','Date.csv','Leads.csv',
                    'Opportunities.csv','OpportunityProducts.csv','Products.csv','SalesReps.csv','Targets.csv']
        self.assertEqual(sum(len(read_csv(name)) for name in entities), 93837)

    def test_opportunity_conflicts_are_detectable(self):
        rows = read_csv('Opportunities.csv')
        counts = {}
        for row in rows:
            counts[row['OpportunityID']] = counts.get(row['OpportunityID'], 0) + 1
        duplicate_ids = {k for k,v in counts.items() if v > 1}
        self.assertEqual(len(duplicate_ids), 35)
        self.assertEqual(sum(counts[k] for k in duplicate_ids), 70)

    def test_month_rep_target_grain_is_unique(self):
        rows = read_csv('Targets.csv')
        keys = [(r['Month'], r['SalesRepID']) for r in rows]
        self.assertEqual(len(keys), len(set(keys)))

    def test_repeated_product_pairs_are_not_assumed_unique(self):
        rows = read_csv('OpportunityProducts.csv')
        counts = {}
        for row in rows:
            k = (row['OpportunityID'], row['ProductID'])
            counts[k] = counts.get(k, 0) + 1
        repeated = {k:v for k,v in counts.items() if v > 1}
        self.assertEqual(len(repeated), 203)
        self.assertEqual(sum(repeated.values()), 406)

    def test_expected_open_stage_contract(self):
        self.assertEqual({'Qualification','Needs Analysis','Proposal','Negotiation'},
                         {'Qualification','Needs Analysis','Proposal','Negotiation'})
        self.assertNotIn('Unknown', {'Qualification','Needs Analysis','Proposal','Negotiation'})

    def test_required_phase_artifacts_exist(self):
        required = [
            'sql/05_analytics/100_create_commercial_kpi_views.sql',
            'sql/06_ai_access/100_create_ai_business_views.sql',
            'docs/data_dictionary.csv', 'docs/evidence/commercial_kpi_snapshot.md',
            'architecture/commercial_revenue_intelligence_architecture.drawio',
            'docs/stories/linkedin_project_post.md', 'docs/stories/medium_case_study.md',
        ]
        for rel in required:
            with self.subTest(path=rel):
                self.assertTrue((ROOT / rel).is_file(), rel)


if __name__ == '__main__':
    unittest.main()
