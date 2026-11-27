"""Isolated v2.6 functional and matched-content performance evidence."""
from pathlib import Path
import argparse,json,os,subprocess,shutil,hashlib,time
import city_packs
R=Path(__file__).resolve().parents[1];Q=R/'build/qa260';Q.mkdir(exist_ok=True)
ENGINE=R.parent.parent/'tools/godot-net/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe'
def dump(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
def run(label,script,compat=False,extra=(),exe=None,vehicles=None,tracks=None):
 out=Q/label;out.mkdir(exist_ok=True);profile=out/'profile';profile.mkdir(exist_ok=True)
 env=dict(os.environ,APPDATA=str(profile),LOCALAPPDATA=str(profile),DOTNET_ROOT=str(R.parent.parent/'tools/dotnet'))
 env['PATH']=env['DOTNET_ROOT']+os.pathsep+env['PATH']
 command=[str(exe or ENGINE)]
 if not exe:command+=['--path',str(R),'--script',script]
 if compat:command+=['--rendering-method','gl_compatibility','--rendering-driver','opengl3']
 command+=['--','--drive-test','--track=astra_coast','--vehicles='+str(vehicles or R/'build/runtime260/GameAssets/vehicles'),'--tracks='+str(tracks or R/'build/preview260/GameAssets/tracks'),'--qa-output='+str(out),*extra]
 controlled=os.name=='nt' and env.get('LEO_CONTROLLED_PERF')=='1'
 context={'normal_priority_requested':controlled,'execution_speed_throttling_disabled':False}
 with (out/'process.log').open('w',encoding='utf-8') as log:
  process=subprocess.Popen(command,cwd=exe.parent if exe else R,env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.NORMAL_PRIORITY_CLASS if controlled else 0)
  if controlled:
   import ctypes
   from ctypes import wintypes
   class PowerState(ctypes.Structure):_fields_=[('Version',wintypes.ULONG),('ControlMask',wintypes.ULONG),('StateMask',wintypes.ULONG)]
   state=PowerState(1,1,0);kernel=ctypes.WinDLL('kernel32',use_last_error=True)
   kernel.SetProcessInformation.argtypes=[wintypes.HANDLE,ctypes.c_int,ctypes.c_void_p,wintypes.DWORD]
   context['execution_speed_throttling_disabled']=bool(kernel.SetProcessInformation(int(process._handle),4,ctypes.byref(state),ctypes.sizeof(state)))
  began=time.monotonic()
  while process.poll() is None:
   time.sleep(.5)
   log.flush()
   current=(out/'process.log').read_text(encoding='utf-8',errors='replace')
   if 'SCRIPT ERROR' in current or 'Parse Error' in current or time.monotonic()-began>1000:
    if os.name=='nt':subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else:process.kill()
    break
  result=subprocess.CompletedProcess(command,process.wait())
 text=(out/'process.log').read_text(encoding='utf-8',errors='replace')
 errors=[line for line in text.splitlines() if any(term in line for term in ['SCRIPT ERROR','Parse Error','Shader compilation failed','Parameter "tex" is null'])]
 warnings=[line for line in text.splitlines() if any(term in line for term in ['leaked','resources still in use','Pages in use'])]
 dump(out/'process.json',{'exit':result.returncode,'errors':errors,'shutdown_warnings':warnings,'execution_context':context})
 assert result.returncode==0 and not errors,(label,result.returncode,errors[:3])
 print('QA260_COMPLETE',label,flush=True)
 return out
def baseline():
 source=R/'build/Release-2.5.0';target=R/'build/baseline260'
 target.mkdir(exist_ok=True)
 for name in ['LeoRacer.exe','LeoRacer.console.exe','data_LeoRacer_windows_x86_64','GameAssets']:
  src=source/name
  if src.is_dir():shutil.copytree(src,target/name,dirs_exist_ok=True)
  elif not (target/name).exists():shutil.copy2(src,target/name)
 engine,entries=city_packs.read_pack(source/'LeoRacer.pck')
 entries.pop('scripts/content/track_check.gd.remap',None)
 entries['scripts/content/track_check.gd']=(R/'tests/release260_benchmark_probe.gd').read_bytes()
 vehicles=R/'build/baseline260-vehicles';vehicles.mkdir(exist_ok=True)
 for src in (R/'build/preview260/GameAssets/vehicles').iterdir():
  if not (src/'vehicle.json').exists():continue
  dest=vehicles/src.name;shutil.copytree(src,dest,dirs_exist_ok=True)
  data=json.loads((dest/'vehicle.json').read_text(encoding='utf-8'));data['core']['min']='2.5.0';dump(dest/'vehicle.json',data)
 # Match vehicle content and official AI membership while retaining the 2.5 code.
 roster=json.loads((R/'assets/config/default-roster-v1.json').read_text(encoding='utf-8'))
 registry=json.loads(entries['assets/config/official-vehicles.json'])
 for row in roster['vehicles']:
  folder=vehicles/row['id'];data=json.loads((folder/'vehicle.json').read_text(encoding='utf-8'))
  row['files']={p.relative_to(folder).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in folder.rglob('*') if p.is_file()}
  registry[row['id']]={'definition':hashlib.sha256((folder/'vehicle.json').read_text(encoding='utf-8').replace('\r\n','\n').encode()).hexdigest(),'model':hashlib.sha256((folder/data['model']).read_bytes()).hexdigest()}
 entries['assets/config/default-roster-v1.json']=json.dumps(roster).encode()
 entries['assets/config/official-vehicles.json']=json.dumps(registry).encode()
 for name in ['vehicle-balance-v2.json','vehicle-presentation-v1.json','vehicle-damage-v1.json']:
  entries['assets/config/'+name]=(R/'assets/config'/name).read_bytes()
 city_packs.write_pack(target/'LeoRacer.pck',engine,entries)
 return target/'LeoRacer.console.exe',vehicles
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('phase',choices=['functional','environment','candidate','native','baseline']);p.add_argument('--dusk',action='store_true');a=p.parse_args()
 if a.phase=='native' and a.dusk:
  import sys,native260
  subprocess.run([sys.executable,str(Path(__file__)),'functional'],cwd=R,check=True)
  subprocess.run([sys.executable,str(Path(__file__)),'environment'],cwd=R,check=True)
  native260.prepare()
  subprocess.run([sys.executable,str(Path(__file__)),'native'],cwd=R,check=True)
 for compat in [False,True]:
  renderer='compatibility' if compat else 'forward'
  if a.phase=='functional':
   out=run('functional-'+renderer,'tests/release260_runtime_test.gd',compat,extra=['--no-captures'])
   row=json.loads((out/'runtime.json').read_text())
   gates={'ui_250ms':row['ui_ms']<=250,'cold_3000ms':row['cold_preview_ms']<=3000,'warm_250ms':row['warm_ms']<=250,'worst_50ms':row['garage_worst_ms']<=50}
   dump(out/'gates.json',{'status':'PASS' if all(gates.values()) else 'FAIL','gates':gates})
   print('GARAGE_GATES',renderer,gates,flush=True)
  elif a.phase=='environment':run('environment-'+renderer,'tests/release260_environment_test.gd',compat)
  elif a.phase=='candidate':run(('dusk-' if a.dusk else 'static-')+renderer,'tests/release260_benchmark.gd',compat,extra=['--qa-dusk'] if a.dusk else [])
  elif a.phase=='native':run(('final-dusk-' if a.dusk else 'final-static-')+renderer,'',compat,extra=['--track-check=performance']+(['--qa-dusk'] if a.dusk else []),exe=R/'build/native260-final/LeoRacer.console.exe')
  else:
   exe,vehicles=baseline();run('baseline-'+renderer,'',compat,['--track-check=performance'],exe,vehicles)
