"""Immutable course/vehicle contract plus scenery provenance for this branch."""
from pathlib import Path
import hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[1]
paths=['assets/tracks/colombo_city/route.json','assets/tracks/colombo_city/course.scn',
       'assets/track-astra.json','assets/catalog/vehicle_bigster.tres',
       'assets/models/srilanka/lotus_tower.glb','assets/models/colombo_city/custom_architecture.glb']
paths += [p.relative_to(ROOT).as_posix() for p in (ROOT/'assets/models/bigster').glob('*.glb')]
hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths}
target=ROOT/'docs/qa-colombo-visuals/protected.json'
if target.exists():assert json.loads(target.read_text())['sha256']==hashes,'Protected course or vehicle changed'
else:
 target.write_text(json.dumps({'base':'e20c7ed','sha256':hashes,
    'landmarks':json.loads((ROOT/'assets/tracks/colombo_city/manifest.json').read_text())['landmarks'],
    'exclusions':json.loads((ROOT/'assets/tracks/colombo_city/placements.json').read_text())['exclusions']},indent=2)+'\n')
print('VISUAL_BASELINE_PASS',len(hashes),'immutable assets')
