"""Live-log diagnostics, isolated profiles, source and extracted Windows builds."""
from pathlib import Path
import argparse,concurrent.futures,json,os,subprocess,sys,time,shutil
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'build/Release-2.3.2'
QA=ROOT/'build/vehicle232'

def run(label,script=None,folder=None,render=False,compat=False,args=(),timeout=300):
    QA.mkdir(parents=True,exist_ok=True)
    env=os.environ.copy();profile=QA/'profiles'/label;profile.mkdir(parents=True,exist_ok=True)
    for name in ['APPDATA','LOCALAPPDATA']:env[name]=str(profile)
    env['DOTNET_ROOT']=str(ROOT.parent.parent/'tools/dotnet');env['PATH']=env['DOTNET_ROOT']+os.pathsep+env['PATH']
    env['LEO_ASSET_ROOT']=str((folder or BASE)/'GameAssets')
    env['VEHICLE_QA_ROOT']=str(QA);env['VEHICLE_QA_OUTPUT']=str(ROOT/'docs/qa-vehicle232'/label)
    if folder:cmd=[str(folder/'LeoRacer.console.exe')]
    else:cmd=[str(ROOT.parent.parent/'tools/godot-net/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe'),'--path',str(ROOT)]
    if not render:cmd+=['--headless']
    if compat:cmd+=['--rendering-method','gl_compatibility','--rendering-driver','opengl3']
    if script and not folder:cmd+=['--script',str(ROOT/script)]
    if script and folder:
        assert script=='tests/vehicle_camera_test.gd','Windows diagnostics must use a compiled opt-in check'
        args=[*args,'--vehicle-check=cameras']
    cmd+=['--','--drive-test',*args]
    if script and not folder:
        vehicles=BASE/'GameAssets/vehicles'
        if script=='tests/vehicle_workshop_test.gd':
            vehicles=QA/'workshop-fixtures'/label
            for key in ['bigster','duster']:shutil.copytree(BASE/'GameAssets/vehicles'/key,vehicles/key,dirs_exist_ok=True)
        cmd+=['--vehicles='+str(vehicles),'--tracks='+str(BASE/'GameAssets/tracks')]
    log=QA/(label+'.log')
    with log.open('w',encoding='utf-8') as output:
        process=subprocess.Popen(cmd,env=env,cwd=folder or ROOT,stdout=output,stderr=subprocess.STDOUT)
        try:code=process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:process.kill();process.wait();code=-999
    text=log.read_text(encoding='utf-8',errors='replace')
    cleanup_markers=['Pages in use exist at exit','resources still in use at exit','RID allocations','Texture with GL ID','Buffer with GL ID','shaders of type SceneShaderGLES3 were never freed','shaders of type SceneForwardClusteredShaderRD were never freed']
    cleanup=[line for line in text.splitlines() if 'ERROR:' in line and any(marker in line for marker in cleanup_markers)]
    errors=[line for line in text.splitlines() if any(marker in line for marker in ['SCRIPT ERROR','Parse Error','Shader compilation failed','Failed loading resource:',"Can't load dependency:",'ERROR:']) and line not in cleanup]
    result={'label':label,'exit_code':code,'errors':errors,'shutdown_diagnostics':len(cleanup),'log':str(log)}
    print(json.dumps(result),flush=True)
    return code==0 and not errors

def races():
    def case(pair):
        track,mode=pair;label='race-'+track+'-'+mode
        return run(label,folder=BASE,args=['--track='+track,'--track-check='+mode,'--qa-output='+str(QA/label)],timeout=240)
    jobs=[(track,mode) for track in ['astra_coast','colombo_city','kandy_lake'] for mode in ['single','split']]
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(case,jobs))
    return all(results)

def performance():
    results=[]
    for version in ['2.3.1','2.3.2']:
        for compat in [False,True]:
            label='performance-'+version+('-compatibility' if compat else '-forward')
            results.append(run(label,folder=ROOT/('build/Release-'+version),render=True,compat=compat,args=['--track=kandy_lake','--track-check=performance','--vehicle=bigster','--qa-output='+str(QA/label)],timeout=180))
    return all(results)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('target',choices=['script','races','performance']);p.add_argument('script',nargs='?');p.add_argument('--label',default='vehicle-test');p.add_argument('--package',action='store_true');p.add_argument('--render',action='store_true');p.add_argument('--compat',action='store_true');a=p.parse_args()
    ok=run(a.label,a.script,BASE if a.package else None,a.render,a.compat) if a.target=='script' else globals()[a.target]()
    sys.exit(0 if ok else 2)
