from pathlib import Path
import os,subprocess,json
R=Path(__file__).resolve().parents[1];Q=R/'build/qa260'
engine=R.parent.parent/'tools/godot-net/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe'
# Compare with the exact released high-frequency controller, not a hand-written clone.
baseline=subprocess.check_output(['git','show','3d37854025589d7e16d94fb6a422020954fe3f6f:scripts/kart.gd'],cwd=R).decode('utf-8')
function=baseline[baseline.index('func _physics_process('):]
next_function=function.find('\nfunc ',1)
if next_function>=0:function=function[:next_function]
Q.mkdir(parents=True,exist_ok=True)
(Q/'baseline_250_controller.gd').write_text('extends LeoKart\n'+function,encoding='utf-8')
results=[]
for mode in (__import__('sys').argv[1:] or ['audit','contacts','replay']):
 out=Q/('regression-'+mode);out.mkdir(parents=True,exist_ok=True)
 env=dict(os.environ,APPDATA=str(out/'profile'),LOCALAPPDATA=str(out/'profile'),DOTNET_ROOT=str(R.parent.parent/'tools/dotnet'),LEO_ASSET_ROOT=str(R/'build/preview260/GameAssets'))
 env['PATH']=env['DOTNET_ROOT']+os.pathsep+env['PATH']
 with (out/'process.log').open('w',encoding='utf-8') as log:
  run=subprocess.run([str(engine),'--headless','--fixed-fps','60','--path',str(R),'--script','tests/release260_collision_test.gd','--','--drive-test','--vehicles='+str(R/'build/runtime260/GameAssets/vehicles'),'--tracks='+str(R/'build/preview260/GameAssets/tracks'),'--quality25-mode='+mode,'--qa-output='+str(out)],cwd=R,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=600)
 text=(out/'process.log').read_text(encoding='utf-8',errors='replace')
 errors=[line for line in text.splitlines() if 'SCRIPT ERROR' in line or 'Parse Error' in line]
 results.append({'mode':mode,'exit':run.returncode,'errors':errors})
 (Q/'regression.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
 assert run.returncode==0 and not errors,(mode,errors[:3])
 print('REGRESSION260_PASS',mode,flush=True)
