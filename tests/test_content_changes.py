import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from content_changes import select
class Changes(unittest.TestCase):
 def test_vehicle_is_independent(self):
  result=select(['assets/models/bigster/bigster.glb'])
  self.assertEqual(result['vehicles'],['bigster']);self.assertFalse(result['core']);self.assertFalse(result['full_roster'])
 def test_track_is_independent(self):
  result=select(['assets/tracks/colombo_city/route.json'])
  self.assertEqual(result['tracks'],['colombo_city']);self.assertFalse(result['core'])
 def test_shared_loader_broadens_checks(self):
  result=select(['scripts/content/asset_resolver.gd'])
  self.assertTrue(result['core']);self.assertTrue(result['full_roster'])
 def test_docs_need_no_export(self):self.assertTrue(select(['docs/MODULARITY.md'])['docs_only'])
if __name__=='__main__':unittest.main()
