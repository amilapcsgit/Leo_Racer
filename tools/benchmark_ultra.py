"""Matched native 2.6/2.7 probes in isolated, disposable diagnostic folders."""
from pathlib import Path
import argparse, ctypes, json, os, shutil, subprocess, time
from ctypes import wintypes
import city_packs
from stage_ultra_content import ROOT, sha

def linked_copy(source, destination):
    source,destination=Path(source),Path(destination)
    if destination.exists():
        assert sha(source)==sha(destination), "Preserve differing diagnostic file"
        return str(destination)
    destination.parent.mkdir(parents=True,exist_ok=True)
    try:os.link(source,destination)
    except OSError:shutil.copy2(source,destination)
    return str(destination)

def prepare(version):
    source=ROOT/('build/Release-2.6.0-Final' if version=='2.6' else 'build/Release-2.7.0-Ultra')
    target=ROOT/('build/perf270-'+version)
    shutil.copytree(source,target,dirs_exist_ok=True,copy_function=linked_copy,ignore=shutil.ignore_patterns('LeoRacer.pck','*.log'))
    engine,entries=city_packs.read_pack(source/'LeoRacer.pck')
    key='scripts/content/track_check.gd';entries.pop(key+'.remap',None)
    entries[key]=(ROOT/'tests/release260_benchmark_probe.gd').read_bytes()
    city_packs.write_pack(target/'LeoRacer.pck',engine,entries)
    return source,target

def run(version,compat,dusk):
    source,target=prepare(version)
    label=version+'-'+('compatibility' if compat else 'forward')+'-'+('dusk' if dusk else 'static')
    output=ROOT/'build/qa270/performance'/label;output.mkdir(parents=True,exist_ok=True)
    profile=output/'profile';profile.mkdir(exist_ok=True)
    env=dict(os.environ,APPDATA=str(profile),LOCALAPPDATA=str(profile),LEO_ASSET_ROOT=str(target/'GameAssets'),DOTNET_ROOT=str(profile/'no-sdk'))
    args=[str(target/'LeoRacer.console.exe'),'--position','-3200,-3200']
    if compat:args+=['--rendering-method','gl_compatibility','--rendering-driver','opengl3']
    args+=['--','--drive-test','--track=astra_coast','--track-check=performance','--vehicles='+str(target/'GameAssets/vehicles'),'--tracks='+str(target/'GameAssets/tracks'),'--qa-output='+str(output)]
    if dusk:args+=['--qa-dusk']
    began=time.monotonic()
    with (output/'process.log').open('w',encoding='utf-8') as log:
        process=subprocess.Popen(args,cwd=target,env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.NORMAL_PRIORITY_CLASS|subprocess.CREATE_NO_WINDOW)
        class PowerState(ctypes.Structure):_fields_=[('Version',wintypes.ULONG),('ControlMask',wintypes.ULONG),('StateMask',wintypes.ULONG)]
        state=PowerState(1,1,0);kernel=ctypes.WinDLL('kernel32',use_last_error=True)
        kernel.SetProcessInformation.argtypes=[wintypes.HANDLE,ctypes.c_int,ctypes.c_void_p,wintypes.DWORD]
        unthrottled=bool(kernel.SetProcessInformation(int(process._handle),4,ctypes.byref(state),ctypes.sizeof(state)))
        try:code=process.wait(timeout=1800)
        except subprocess.TimeoutExpired:process.kill();process.wait();code=-999
    text=(output/'process.log').read_text(encoding='utf-8',errors='replace')
    errors=[line for line in text.splitlines() if any(x in line for x in ['SCRIPT ERROR','Parse Error','CrashHandlerException'])]
    rows=json.loads((output/'performance.json').read_text(encoding='utf-8')) if (output/'performance.json').exists() else []
    report={'status':'PASS' if code==0 and not errors and len(rows)==6 else 'FAIL','exit':code,'errors':errors,'seconds':time.monotonic()-began,'source_core_sha256':sha(source/'LeoRacer.pck'),'diagnostic_core_sha256':sha(target/'LeoRacer.pck'),'execution_speed_throttling_disabled':unthrottled,'normal_priority':True,'rows':len(rows),'p95_goal_ms':16.7,'p95_misses':[r for r in rows if r['p95_ms']>16.7]}
    (output/'process.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(label,report,flush=True)
    return report['status']=='PASS'

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('version',choices=['2.6','2.7']);p.add_argument('--compatibility',action='store_true');p.add_argument('--dusk',action='store_true');a=p.parse_args()
    raise SystemExit(0 if run(a.version,a.compatibility,a.dusk) else 1)
