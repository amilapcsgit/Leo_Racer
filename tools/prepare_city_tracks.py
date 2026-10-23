"""Register the preserved Astra circuit; expanded Colombo is baked separately."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]
folder=ROOT/'assets/tracks/astra_coast';folder.mkdir(parents=True,exist_ok=True)
route=(ROOT/'assets/track-astra.json').read_bytes();(folder/'route.json').write_bytes(route)
manifest={'format':1,'asset_api':1,'id':'astra_coast','name':'Astra Lotus Coast','course_revision':1,
          'route':'route.json','world_kind':'astra','lighting':'res://assets/config/astra.tres',
          'description':'The original 1.9 km coast, harbour and garden circuit.','packs':[]}
(folder/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
registry={}
for p in (ROOT/'assets/tracks').glob('*/manifest.json'):
    data=json.loads(p.read_text(encoding='utf-8'))
    registry[data['id']+':'+str(data['course_revision'])]=hashlib.sha256((p.parent/data['route']).read_bytes()).hexdigest()
(ROOT/'assets/config/official-tracks.json').write_text(json.dumps(registry,indent=2)+'\n',encoding='utf-8')
print('TRACK_REGISTRY',list(registry))
