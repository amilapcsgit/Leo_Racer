"""Native diagnostic harness: retain the 2.5 engine, replace only tested game data.

This is not the deliverable preview export. It permits release-template performance
measurement before the Windows preview build is authorized by the release gates.
"""
from pathlib import Path
import argparse,hashlib,json,re,shutil,subprocess
import city_packs
R=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def prepare():
 source=R/'build/Release-2.5.0';target=R/'build/native260-final';target.mkdir(exist_ok=True)
 for name in ['LeoRacer.exe','LeoRacer.console.exe','data_LeoRacer_windows_x86_64','GameAssets']:
  src=source/name
  if src.is_dir():shutil.copytree(src,target/name,dirs_exist_ok=True)
  else:shutil.copy2(src,target/name)
 shutil.copytree(R/'build/runtime260/GameAssets/vehicles',target/'GameAssets/vehicles',dirs_exist_ok=True)
 shutil.copytree(R/'build/preview260/GameAssets/environments',target/'GameAssets/environments',dirs_exist_ok=True)
 shutil.copy2(R/'build/preview260/GameAssets/catalog.json',target/'GameAssets/catalog.json')
 engine,entries=city_packs.read_pack(source/'LeoRacer.pck')
 changed=set(subprocess.check_output(['git','diff','--name-only'],cwd=R,text=True).splitlines())
 changed.update(str(p.relative_to(R)).replace('\\','/') for p in (R/'scripts').rglob('*.gd'))
 # The source scripts are loaded by the same release engine used by 2.5.
 # Gameplay and scenery resources not named below remain byte-identical.
 changed.update(str(p.relative_to(R)).replace('\\','/') for p in (R/'assets/config').glob('*.json'))
 for name in changed:
  p=R/name
  if p.suffix not in ['.gd','.gdshader','.json'] or not p.is_file():continue
  if not name.startswith(('scripts/','assets/config/','shaders/')):continue
  entries.pop(name+'.remap',None);entries[name]=p.read_bytes()
 class_key='.godot/global_script_class_cache.cfg'
 old=entries[class_key].decode('utf-8')
 current=(R/class_key).read_text(encoding='utf-8')
 for block in re.findall(r'\{\s*"base":.*?\n\}',current,re.S):
  match=re.search(r'"class":\s*&?"([^"]+)"',block)
  if match and '"'+match[1]+'"' not in old:old=old.rstrip().removesuffix(']')+', '+block+']\n'
 entries[class_key]=old.encode('utf-8')
 key='scripts/content/track_check.gd';entries.pop(key+'.remap',None)
 entries[key]=(R/'tests/release260_benchmark_probe.gd').read_bytes()
 city_packs.write_pack(target/'LeoRacer.pck',engine,entries)
 dll=R/'.godot/mono/temp/bin/ExportDebug/LeoRacer.dll'
 assert dll.is_file(),'Compile ExportDebug .NET bridge before preparing the harness'
 destination=next((target/'data_LeoRacer_windows_x86_64').rglob('LeoRacer.dll'))
 shutil.copy2(dll,destination)
 report={'purpose':'native diagnostic harness; not preview release','base_commit':'3d37854025589d7e16d94fb6a422020954fe3f6f','engine_unchanged':sha(target/'LeoRacer.exe')==sha(source/'LeoRacer.exe'),'core_sha256':sha(target/'LeoRacer.pck'),'assembly_sha256':sha(destination),'default_cars':21}
 (target/'harness.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
 print('NATIVE260_PREPARED',flush=True)
if __name__=='__main__':prepare()
