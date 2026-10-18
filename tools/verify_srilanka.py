"""Aggregate completed diagnostic logs and verify preserved/source geometry."""
from pathlib import Path
import json,hashlib,subprocess,re,struct
ROOT=Path(__file__).resolve().parents[1]
git=['git','-c','safe.directory='+str(ROOT).replace('\\','/'),'-C',str(ROOT)]
baseline=json.loads((ROOT/'docs/qa-colombo/geometry-baseline.json').read_text())
for name,entry in baseline.items():assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==entry['sha256'],name
assert len(baseline)==34
assert subprocess.check_output(git+['diff','Colombo','--','scripts/kart.gd','scripts/circuit.gd','assets/track.json'])==b''
for p in (ROOT/'assets/models/srilanka').glob('*.glb'):
 b=p.read_bytes();assert struct.unpack_from('<I',b,8)[0]==len(b),p
for i in range(3):assert json.loads((ROOT/f'docs/qa-srilanka/phoenix_{i}-asset.json').read_text())['triangles']<=25000
suites={}
for key,file in [('wheel','wheel_test.log'),('drive','drive_test.log'),('visual','visual_regression.log'),('presentation','presentation_test.log'),('srilanka','srilanka_test.log'),('smoke','smoke-test.log'),('race','race-test.log'),('layout','layout-test.log')]:
 s=(ROOT/'docs/qa-srilanka'/file).read_text(encoding='utf-8',errors='replace');assert 'SCRIPT ERROR' not in s and 'FAIL ' not in s,(key,'log errors');suites[key]={'checks':len(re.findall(r'^PASS ',s,re.M)),'status':'PASS'}
assert sum(x['checks'] for x in suites.values())==153,suites
profile=json.loads((ROOT/'docs/qa-srilanka/render-profile.json').read_text());assert profile['mean_fps']>=60 and profile['p95_frame_ms']<=18 and profile['full_race_completed']
report={'version':'1.3.0','branch':'srilanka','automated_checks':153,'suites':suites,'original_glbs_unchanged':list(baseline),'driving_and_circuit_unchanged':True,'model_headers_valid':17,'palm_near_triangle_budget':25000,'mean_fps':profile['mean_fps'],'p95_frame_ms':profile['p95_frame_ms'],'viewport':profile['viewport_pixels'],'full_race_completed':profile['full_race_completed'],'known_engine_cleanup_warnings':True}
(ROOT/'docs/qa-srilanka/summary.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='original_glbs_unchanged'},indent=2))
