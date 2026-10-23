"""Record protected v1.7 source geometry and baseline package sizes."""
from pathlib import Path
import hashlib, json, struct

ROOT = Path(__file__).resolve().parents[1]
paths = [ROOT / 'assets/track-astra.json', ROOT / 'assets/catalog/vehicle_bigster.tres',
         ROOT / 'assets/models/srilanka/lotus_tower.glb']
paths += list((ROOT / 'assets/models/bigster').glob('*.glb'))
paths += list((ROOT / 'assets/models/astra').glob('*.glb'))
protected = {str(p.relative_to(ROOT)).replace('\\', '/'): hashlib.sha256(p.read_bytes()).hexdigest()
             for p in paths if p.is_file()}
architecture = []
for p in [ROOT / 'assets/models/srilanka/world.glb', ROOT / 'assets/models/lotus_coast.glb']:
    if not p.exists(): continue
    data = p.read_bytes(); size = struct.unpack_from('<I', data, 12)[0]
    doc = json.loads(data[20:20+size])
    architecture.append({'file':p.relative_to(ROOT).as_posix(), 'sha256':hashlib.sha256(data).hexdigest(),
                         'nodes':[n.get('name','') for n in doc.get('nodes',[])]})
report = {'base':'ac37cc6', 'protected_sha256':protected, 'preserved_architecture':architecture,
          'landmarks':['AuthenticLotusTower','Galle Face Green','Independence pavilion','Lotus garden'],
          'baseline_packages':{p.relative_to(ROOT).as_posix():p.stat().st_size
              for p in (ROOT/'build').rglob('*.exe') if p.name in ['Leo Racer.exe','Leo Racer Launcher.exe']}}
folder = ROOT / 'docs/qa-colombo-city'; folder.mkdir(exist_ok=True)
target = folder/'baseline.json'
if target.exists():
    previous=json.loads(target.read_text())
    assert previous['protected_sha256']==protected, 'Protected geometry or wheel bindings changed'
    print('BASELINE protected geometry unchanged:',len(protected),'files')
else:
    target.write_text(json.dumps(report,indent=2)+'\n')
    print('BASELINE recorded:',len(protected),'protected files')
