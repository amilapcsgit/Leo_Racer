"""Independent lighting content stage; the delivered 2.6 preview is read-only."""
from pathlib import Path
import json,shutil,hashlib
R=Path(__file__).resolve().parents[1]
BASE=R/'build/Preview-2.6.0'
STAGE=R/'build/lighting-content'
def dump(path,value):
 path.parent.mkdir(parents=True,exist_ok=True)
 path.write_text(json.dumps(value,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
def stage():
 assert not (STAGE/'GameAssets').exists(),'Use the independent existing stage rather than overwriting compiled derivatives'
 shutil.copytree(BASE/'GameAssets',STAGE/'GameAssets')
 dump(STAGE/'source.json',{'commit':'857918916a961009258fb91730153e2a67af7609','source':str(BASE),'core_sha256':hashlib.sha256((BASE/'LeoRacer.pck').read_bytes()).hexdigest()})
def fingerprints():
 registry=json.loads((R/'assets/config/official-tracks.json').read_text(encoding='utf-8'))
 packs=json.loads((R/'assets/config/official-track-content.json').read_text(encoding='utf-8'))
 for path in (STAGE/'GameAssets/tracks').glob('*/manifest.json'):
  data=json.loads(path.read_text(encoding='utf-8'));key=data['id']+':'+str(data['course_revision'])
  registry[key]=hashlib.sha256((path.parent/data['route']).read_bytes()).hexdigest()
  packs[key]=[row['sha256'] for row in data.get('packs',[])]
 dump(R/'assets/config/official-tracks.json',registry)
 dump(R/'assets/config/official-track-content.json',packs)
if __name__=='__main__':
 import sys
 globals()[sys.argv[1] if len(sys.argv)>1 else 'stage']()
