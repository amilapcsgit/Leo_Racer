"""Audit a modular distribution without relying on Godot's editor import cache."""
from pathlib import Path
import argparse, hashlib, json, zipfile
from city_packs import read_pack
from content import read, sha, model_document, ROOT

def main():
 p=argparse.ArgumentParser();p.add_argument('--folder',type=Path,required=True);p.add_argument('--archive',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 sources=read(ROOT/'content/vehicle-sources.json');folder=a.folder;vehicles=[]
 for directory in sorted((folder/'GameAssets/vehicles').iterdir()):
  if not directory.is_dir() or not (directory/'vehicle.json').is_file():continue
  data=read(directory/'vehicle.json');key=data['id'];assert key in sources
  for name in ['model.glb','vehicle.json','thumbnail.png','LICENSE.txt']:assert (directory/name).is_file()
  assert sha(directory/'model.glb')==sha(ROOT/sources[key]['model'].removeprefix('res://'))
  model_document(directory/'model.glb');vehicles.append(key)
 basenames={Path(row['model']).name for row in sources.values()};packed=[];packs=[]
 for path in sorted(folder.rglob('*.pck')):
  _,entries=read_pack(path);packs.append(path.relative_to(folder).as_posix())
  for name in entries:
   if any(Path(name).name.startswith(base) for base in basenames):packed.append(path.name+':'+name)
 assert not packed,'Vehicle model/remap is still packed: '+str(packed)
 with zipfile.ZipFile(a.archive) as archive:
  assert archive.testzip() is None
  for key in vehicles:
   data=archive.read('LeoRacer/GameAssets/vehicles/'+key+'/model.glb');assert hashlib.sha256(data).hexdigest()==sha(folder/'GameAssets/vehicles'/key/'model.glb')
 def size(path):return sum(p.stat().st_size for p in path.rglob('*') if p.is_file())
 managed=read(folder/'.managed-build.json');installed=sum((folder/name).stat().st_size for name in managed)
 report={'status':'PASS','vehicles':vehicles,'packed_vehicle_models':packed,'packs_audited':packs,'loose_models_match_sources':True,'archive_crc':'PASS','archive_sha256':sha(a.archive),'exe_bytes':(folder/'LeoRacer.exe').stat().st_size,'core_bytes':(folder/'LeoRacer.pck').stat().st_size,'vehicle_bytes':size(folder/'GameAssets/vehicles'),'texture_bytes':size(folder/'GameAssets/textures'),'shared_asset_bytes':sum(p.stat().st_size for p in (folder/'GameAssets').rglob('*') if p.is_file() and not any(x in ['vehicles','tracks','textures'] for x in p.relative_to(folder/'GameAssets').parts)),'tracks':{p.name:size(p) for p in (folder/'GameAssets/tracks').iterdir() if p.is_dir()},'installed_bytes':installed,'compressed_bytes':a.archive.stat().st_size}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print('MODULAR_DISTRIBUTION_AUDIT PASS vehicles='+str(len(vehicles)))
if __name__=='__main__':main()
