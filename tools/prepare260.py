"""Stage the approved 21-car roster without touching source assets or installations."""
from pathlib import Path
import json,hashlib,shutil
ROOT=Path(__file__).resolve().parents[1];BASE=ROOT.parent.parent
STAGE=ROOT/'build/preview260';VEHICLES=STAGE/'GameAssets/vehicles'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
def prepare():
 spec=json.loads((ROOT/'assets/config/default-roster-v1.json').read_text(encoding='utf-8'))
 source=ROOT/'build/Release-2.5.0/GameAssets'
 if not (STAGE/'GameAssets/catalog.json').exists():shutil.copytree(source,STAGE/'GameAssets',dirs_exist_ok=True)
 for key,src in [('duster',BASE/'Duster_My_2014/package/GameAssets/vehicles/duster'),('duster_2024',BASE/'Duster_2024/package/GameAssets/vehicles/duster_2024')]:
  target=VEHICLES/key;target.mkdir(parents=True,exist_ok=True)
  shutil.copytree(src,target,dirs_exist_ok=True)
  if key=='duster':
   presets=target/'Duster_My_2014_paint_presets.json';colors=json.loads(presets.read_text(encoding='utf-8'))
   for color in colors['presets']:
    if color['id'].startswith('nero_'):color['id']='nero_nacre';color['name']='Nero Nacr\u00e9'
   dump(presets,colors)
  data=json.loads((target/'vehicle.json').read_text(encoding='utf-8'));data['core']['min']='2.6.0'
  import copy
  recipe=json.loads((ROOT/'content/releases/2.6.0.json').read_text(encoding='utf-8'))
  for driver,ratio in recipe.get('driver_fit_scales',{}).get(key,{}).items():
   fit=copy.deepcopy(data.get('driver_fits',{}).get(driver,data['seat']))
   fit['basis']=[[value*ratio for value in axis] for axis in fit['basis']];data.setdefault('driver_fits',{})[driver]=fit
  if key in recipe.get('driver_seat_offsets',{}):
   offset=recipe['driver_seat_offsets'][key]
   original=copy.deepcopy(data['seat'])
   data['seat']['origin']=[value+offset[i] for i,value in enumerate(original['origin'])]
   for driver in ['hedgehog','lion','elephant','parrot','human','mario']:
    fit=copy.deepcopy(data.get('driver_fits',{}).get(driver,original));fit['origin']=[value+offset[i] for i,value in enumerate(fit['origin'])];data.setdefault('driver_fits',{})[driver]=fit
  dump(target/'vehicle.json',data)
  row={'id':key,'display_name':data['display_name'],'files':{p.relative_to(target).as_posix():sha(p) for p in target.rglob('*') if p.is_file() and p.name not in ['model.glb','thumbnail.png']}}
  # Preserve the expected model for the 2024 package; the 2014 package uses a named model.
  for name in [data['model'],data['thumbnail']]:row['files'][name]=sha(target/name)
  found=next((i for i,v in enumerate(spec['vehicles']) if v['id']==key),None)
  if found is None:spec['vehicles'].append(row)
  else:spec['vehicles'][found]=row
 spec['id']='focused21_v2';assert len(spec['vehicles'])==21 and spec['vehicles'][-1]['id']=='duster_2024'
 dump(ROOT/'assets/config/default-roster-v1.json',spec)
 registry=json.loads((ROOT/'assets/config/official-vehicles.json').read_text(encoding='utf-8'))
 for key in ['duster','duster_2024']:
  p=VEHICLES/key;data=json.loads((p/'vehicle.json').read_text(encoding='utf-8'))
  registry[key]={'definition':hashlib.sha256((p/'vehicle.json').read_text(encoding='utf-8').replace('\r\n','\n').encode()).hexdigest(),'model':sha(p/data['model'])}
 dump(ROOT/'assets/config/official-vehicles.json',registry)
 presentation=json.loads((ROOT/'assets/config/vehicle-presentation-v1.json').read_text(encoding='utf-8'));presentation['duster_2024']={'length':4.343,'source':'Duster 2024 approved source derivative'};dump(ROOT/'assets/config/vehicle-presentation-v1.json',presentation)
 balance=json.loads((ROOT/'assets/config/vehicle-balance-v2.json').read_text(encoding='utf-8'));balance['vehicles']['duster_2024']=balance['vehicles']['duster'];dump(ROOT/'assets/config/vehicle-balance-v2.json',balance)
 project=ROOT/'project.godot';project.write_text(project.read_text(encoding='utf-8').replace('config/version="2.5.0"','config/version="2.6.0"'),encoding='utf-8')
 dump(STAGE/'default-roster-v1.json',spec)
 print('STAGED',VEHICLES)
if __name__=='__main__':prepare()
