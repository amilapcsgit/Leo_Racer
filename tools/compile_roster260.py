"""Compile content only; publishing remains gated by the release checks."""
from pathlib import Path
import subprocess,os,json,shutil,hashlib
R=Path(__file__).resolve().parents[1]
stage=R/'build/preview260/GameAssets/vehicles'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,v):p.write_text(json.dumps(v,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
spec=json.loads((R/'assets/config/default-roster-v1.json').read_text(encoding='utf-8'))
registry={}
for row in spec['vehicles']:
 key=row['id'];source=stage/key;dest=R/'build/compiled260'/key
 env=dict(os.environ,APPDATA=str(R/'build/profile260'))
 with (R/f'build/compile-{key}.log').open('w',encoding='utf-8') as log:
  result=subprocess.run(['C:/godot/Godot_v4.7.2-stable_win64_console.exe','--headless','--path',str(R),'--script','tools/compile_vehicle260.gd','--log-file',str(R/f'build/compiler-{key}.log'),'--',f'--source={source}',f'--destination={dest}'],stdout=log,stderr=log,env=env)
 text=(R/f'build/compile-{key}.log').read_text(encoding='utf-8')
 if result.returncode or 'SCRIPT ERROR:' in text or 'ERROR:' in text:raise RuntimeError(f'{key}: compiler failed; see log')
 data=json.loads((dest/'vehicle.json').read_text(encoding='utf-8'))
 # Keep source metadata and copyright notices alongside runtime content.
 for file in source.rglob('*'):
  if file.is_file() and file.suffix.lower() not in ['.glb','.blend','.pck','.scn'] and file.name!='vehicle.json':
   target=dest/file.relative_to(source);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(file,target)
 runtime=R/'build/runtime260/GameAssets/vehicles'/key
 runtime.mkdir(parents=True,exist_ok=True)
 for file in dest.rglob('*'):
  if file.is_file() and file.name not in ['model.scn','shader_warmup.scn','compile-report.json'] and 'textures' not in file.relative_to(dest).parts:
   target=runtime/file.relative_to(dest);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(file,target)
 row['files']={p.relative_to(runtime).as_posix():sha(p) for p in runtime.rglob('*') if p.is_file()}
 registry[key]={'definition':hashlib.sha256((runtime/'vehicle.json').read_text(encoding='utf-8').encode()).hexdigest(),'model':sha(runtime/'vehicle.pck')}
 print('COMPILED',key,flush=True)
dump(R/'assets/config/default-roster-v1.json',spec)
dump(R/'assets/config/official-vehicles.json',registry)
dump(R/'build/runtime260/default-roster-v1.json',spec)
print('ROSTER_COMPILED',flush=True)
