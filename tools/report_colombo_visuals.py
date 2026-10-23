"""Audit external development content and report installed/download sizes separately."""
from pathlib import Path
import argparse,hashlib,json,zipfile
from city_packs import read_pack
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--folder',type=Path,default=ROOT/'build/ColomboVisuals')
parser.add_argument('--archive',type=Path,default=ROOT/'dist/LeoRacer-2.0.0-colombo-visuals-dev-win64.zip')
args=parser.parse_args();folder=args.folder.resolve();archive=args.archive.resolve()
catalog=json.loads((folder/'GameAssets/catalog.json').read_text(encoding='utf-8-sig'))
assert catalog['content']['colombo_visuals']['revision']==2
names=set();packs=list((folder/'GameAssets').rglob('*.pck'))
for p in [folder/'LeoRacer.pck',*packs]:names.update(read_pack(p)[1])
for name in ['assets/models/colombo_city/modules.json','assets/models/colombo_city/recipes.json',
             'assets/art/colombo/lighting.json','assets/tracks/colombo_city/backdrop.scn']:
 assert name in names,name
assert not any(name.startswith(('source_assets/','tools/','tests/')) for name in names)
for track in ['astra_coast','colombo_city']:
 d=json.loads((folder/'GameAssets/tracks'/track/'manifest.json').read_text())
 assert d['course_revision']==1
with zipfile.ZipFile(archive) as z:assert z.testzip() is None
report={'status':'PASS','branch':'colombo-visuals','development_only':True,
 'exe_bytes':(folder/'LeoRacer.exe').stat().st_size,'core_bytes':(folder/'LeoRacer.pck').stat().st_size,
 'shared_assets_bytes':sum(p.stat().st_size for p in packs if 'tracks' not in p.relative_to(folder/'GameAssets').parts),
 'category_pack_bytes':{p.relative_to(folder/'GameAssets').as_posix():p.stat().st_size for p in packs},
 'track_bytes':{p.name:sum(f.stat().st_size for f in p.rglob('*') if f.is_file()) for p in (folder/'GameAssets/tracks').iterdir() if p.is_dir()},
 'installed_bytes':sum(p.stat().st_size for p in folder.rglob('*') if p.is_file()),
 'compressed_bytes':archive.stat().st_size,'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),
 'archive':str(archive),'compiled_resources':len(names),'raw_authoring_sources_shipped':False}
target=ROOT/'docs/qa-colombo-visuals/package.json'
target.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
