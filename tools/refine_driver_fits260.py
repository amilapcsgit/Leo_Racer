"""Apply measured cabin clearances to output metadata; source masters stay unchanged."""
from pathlib import Path
import json,hashlib,copy,shutil
import city_packs
R=Path(__file__).resolve().parents[1];W=R.parent.parent;Q=R/'build/qa260'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def dump(p,v):p.write_text(json.dumps(v,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
rows=read(Q/'driver-fits.json')
if not (Q/'driver-fits-before.json').exists():shutil.copy2(Q/'driver-fits.json',Q/'driver-fits-before.json')
scales={row['driver']:row['scale_ratio'] for row in rows if row['vehicle']=='duster_2024' and row['scale_ratio']<.9999}
if not scales:scales=read(R/'content/releases/2.6.0.json').get('driver_fit_scales',{}).get('duster_2024',{})
base=read(W/'Duster_2024/package/GameAssets/vehicles/duster_2024/vehicle.json')
for folder in [R/'build/preview260/GameAssets/vehicles/duster_2024',R/'build/runtime260/GameAssets/vehicles/duster_2024',R/'build/Preview-2.6.0/GameAssets/vehicles/duster_2024']:
 data=read(folder/'vehicle.json');data['driver_fits']=copy.deepcopy(base.get('driver_fits',{}))
 for driver,ratio in scales.items():
  fit=copy.deepcopy(data['driver_fits'].get(driver,base['seat']))
  fit['basis']=[[value*ratio for value in axis] for axis in fit['basis']];data['driver_fits'][driver]=fit
 # Leave headroom beneath the sloping front roof, not only its highest point.
 data['seat']=copy.deepcopy(base['seat']);data['seat']['origin'][1]-=.08
 for driver in ['hedgehog','lion','elephant','parrot','human','mario']:
  fit=copy.deepcopy(data['driver_fits'].get(driver,base['seat']));fit['origin'][1]-=.08;data['driver_fits'][driver]=fit
 dump(folder/'vehicle.json',data)
recipe=read(R/'content/releases/2.6.0.json');recipe['driver_fit_scales']={'duster_2024':scales};recipe['driver_seat_offsets']={'duster_2024':[0.,-.08,0.]};dump(R/'content/releases/2.6.0.json',recipe)
roster=read(R/'assets/config/default-roster-v1.json');registry={}
for row in roster['vehicles']:
 folder=R/'build/runtime260/GameAssets/vehicles'/row['id']
 row['files']={p.relative_to(folder).as_posix():sha(p) for p in folder.rglob('*') if p.is_file()}
 registry[row['id']]={'definition':hashlib.sha256((folder/'vehicle.json').read_text(encoding='utf-8').replace('\r\n','\n').encode()).hexdigest(),'model':sha(folder/'vehicle.pck')}
dump(R/'assets/config/default-roster-v1.json',roster);dump(R/'assets/config/official-vehicles.json',registry)
for p in [R/'build/runtime260/default-roster-v1.json',R/'build/Preview-2.6.0/default-roster-v1.json']:dump(p,roster)
engine,entries=city_packs.read_pack(R/'build/Preview-2.6.0/LeoRacer.pck')
for name in ['default-roster-v1.json','official-vehicles.json']:entries['assets/config/'+name]=(R/'assets/config'/name).read_bytes()
city_packs.write_pack(R/'build/Preview-2.6.0/LeoRacer.pck',engine,entries)
meta=read(R/'build/Preview-2.6.0/release-build.json');meta['core_sha256']=sha(R/'build/Preview-2.6.0/LeoRacer.pck');dump(R/'build/Preview-2.6.0/release-build.json',meta)
print('REFINED_CABIN_FITS',scales)
