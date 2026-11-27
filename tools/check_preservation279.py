"""Read-only hash comparisons; only this release's evidence is written."""
from pathlib import Path
import hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT.parents[1]/'sources'
manifest=json.loads((ROOT/'docs/modular-garage/asset-provenance.json').read_text(encoding='utf-8'))
errors=[];originals=[];inherited=[]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for entry in manifest:
    path=SRC/entry['source']
    if not path.is_file() or sha(path)!=entry['sha256']:errors.append('Original source mismatch: '+entry['source'])
    originals.append({'file':entry['source'],'sha256':sha(path) if path.exists() else None})
baseline='894d196'
paths=subprocess.check_output(['git','ls-tree','-r','--name-only',baseline,'assets/models','assets/track.json','assets/track-astra.json','content/ultra'],cwd=ROOT,text=True).splitlines()
for name in paths:
    if not name.endswith(('.glb','.json','.pck')):continue
    original=subprocess.check_output(['git','show',baseline+':'+name],cwd=ROOT)
    current=(ROOT/name).read_bytes()
    same=json.loads(original)==json.loads(current) if name.endswith('.json') else original==current
    if not same:errors.append('Inherited model/track/package changed: '+name)
    inherited.append({'file':name,'unchanged':same,'sha256':hashlib.sha256(current).hexdigest()})
result={'status':'PASS' if not errors else 'FAIL','errors':errors,'baseline':baseline,'originals':originals,'inherited':inherited}
out=ROOT/'build/qa279';out.mkdir(parents=True,exist_ok=True)
(out/'source-preservation.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print('SOURCE_PRESERVATION',result['status'],len(originals),'originals,',len(inherited),'inherited models/tracks/packs')
raise SystemExit(bool(errors))
