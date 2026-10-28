"""Exercise the actual self-contained Windows preview with SDK paths removed."""
from pathlib import Path
import os,json,hashlib
import verify_distinct as verify
R=Path(__file__).resolve().parents[1];BASE=R/'build/Preview-2.6.0';Q=R/'build/qa260/export';Q.mkdir(parents=True,exist_ok=True)
verify.QA=Q
os.environ['LEO_ASSET_ROOT']=str(BASE/'GameAssets')
cases=[('content',['--verify-content'],False,False),('camera-forward',['--vehicle-check=cameras'],True,False),('camera-compatibility',['--vehicle-check=cameras'],True,True)]
cases += [(track+'-'+mode,['--track='+track,'--track-check='+mode],False,False) for track in ['astra_coast','colombo_city','kandy_lake'] for mode in ['single','split']]
results=[]
for label,args,render,compat in cases:
 ok=verify.run(label,BASE,args=args,render=render,compat=compat,vehicles=BASE/'GameAssets/vehicles',timeout=400)
 results.append({'case':label,'pass':ok})
 report={'status':'PASS' if all(row['pass'] for row in results) and len(results)==len(cases) else 'FAIL','cases':results,'sdk_removed':True,'core_sha256':hashlib.sha256((BASE/'LeoRacer.pck').read_bytes()).hexdigest()}
 (R/'build/qa260/export-smoke.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
 assert ok,'Export smoke failed: '+label
print('EXPORT260_PASS',flush=True)
