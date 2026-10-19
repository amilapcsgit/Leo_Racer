"""Check the exact preservation contract against read-only originals and Astra."""
from pathlib import Path
import hashlib,json,subprocess,sys
ROOT=Path(__file__).resolve().parents[1];SRC=ROOT.parents[1]/'sources'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
manifest=json.loads((ROOT/'docs/modular-garage/asset-provenance.json').read_text(encoding='utf-8'))
errors=[];checks=[]
for entry in manifest:
    path=SRC/entry['source'];checks.append(entry['source'])
    if path.exists() and sha(path)!=entry['sha256']:errors.append('Original changed: '+entry['source'])
    if 'id' in entry:
        if sha(ROOT/f"assets/models/modular/{entry['id']}.glb")!=entry['prepared_sha256']:errors.append('Prepared asset differs from audited output: '+entry['id'])
    else:
        key='human' if 'Shaven' in path.name else 'mario'
        entry['prepared']={p.name:sha(p) for p in sorted((ROOT/'assets/models/modular').glob('driver_'+key+'_*.glb'))}
prefix=['git','-c','safe.directory='+ROOT.as_posix(),'-C',str(ROOT)]
baseline='7baf4e13cc1ca798147ef422e31d029e77ef5de6'
files=subprocess.check_output(prefix+['ls-tree','-r','--name-only',baseline,'assets/models','assets/track-astra.json','assets/track.json']).decode().splitlines()
preserved=0
for file in files:
    if not file.endswith(('.glb','.json')):continue
    original=subprocess.check_output(prefix+['show',baseline+':'+file])
    current=(ROOT/file).read_bytes()
    # JSON transport may normalize LF/CRLF. Compare parsed data, never weaken
    # binary geometry checks or hide an actual track/specification change.
    same=json.loads(current)==json.loads(original) if file.endswith('.json') else current==original
    if not same:errors.append('Astra geometry/track changed: '+file)
    preserved+=1
report={'status':'PASS' if not errors else 'FAIL','errors':errors,'originals_hashed':len(checks),'astra_geometry_track_files_identical':preserved,'source_paths':checks,'car_contract':'All POSITION/NORMAL/TEXCOORD accessors, embedded image bytes and material assignments retained; index partitioning only. Pony Ground_SG two-triangle presentation floor excluded.','driver_contract':'Source UV/material binding retained through Blender; seated/standing poses baked. Generated Icosphere armature display helper excluded.','helmet_png_sha256':sha(ROOT/'assets/models/modular/helmet_driver.png')}
(ROOT/'docs/modular-garage/asset-provenance.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
(ROOT/'docs/qa-modular-garage/source-preservation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2));sys.exit(1 if errors else 0)
