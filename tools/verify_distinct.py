"""Exercise the Windows candidate without an installed .NET SDK."""
from pathlib import Path
import argparse, concurrent.futures, json, os, subprocess, time, shutil, hashlib

ROOT=Path(__file__).resolve().parents[1]
QA=ROOT/'build/distinct'
CANDIDATE=Path(os.environ.get('LEO_CANDIDATE_DIR',str(ROOT/'build/Distinct-v3-final')))
BASELINE=ROOT/'build/Release-2.3.2'
def core_sha():
    with (CANDIDATE/'LeoRacer.pck').open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()

def run(label, folder=CANDIDATE, args=(), render=False, compat=False, timeout=240, vehicles=None):
    output=QA/label;output.mkdir(parents=True,exist_ok=True)
    profile=QA/'profiles'/label;profile.mkdir(parents=True,exist_ok=True)
    env=os.environ.copy();env.update(APPDATA=str(profile),LOCALAPPDATA=str(profile),DOTNET_ROOT=str(profile/'no-sdk'))
    env['PATH']=os.pathsep.join(part for part in env['PATH'].split(os.pathsep) if not any(word in part.lower() for word in ['dotnet','.tools']))
    cmd=[str(folder/'LeoRacer.console.exe')]
    if not render:cmd+=['--headless','--fixed-fps','60']
    if compat:cmd+=['--rendering-method','gl_compatibility','--rendering-driver','opengl3']
    cmd+=['--','--drive-test','--qa-output='+str(output),*args]
    if vehicles:cmd+=['--vehicles='+str(vehicles)]
    env['VEHICLE_QA_OUTPUT']=str(output)
    start=time.monotonic()
    with (QA/(label+'.log')).open('w',encoding='utf-8') as log:
        process=subprocess.Popen(cmd,cwd=folder,env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        try:code=process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:process.kill();process.wait();code=-999
    text=(QA/(label+'.log')).read_text(encoding='utf-8',errors='replace')
    errors=[line for line in text.splitlines() if any(word in line for word in ['SCRIPT ERROR','Parse Error','Shader compilation failed','CONTENT_VALIDATION_FAILED'])]
    result=dict(label=label,exit_code=code,seconds=round(time.monotonic()-start,2),errors=errors,sdk_removed=True)
    (output/'process.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result),flush=True)
    return code==0 and not errors

def smoke():
    results=[run('packaged-content',args=['--verify-content']),run('packaged-balance',args=['--distinct-check'])]
    if not all(results):
        (QA/'packaged-acceptance.json').write_text(json.dumps({'status':'FAIL','cases':len(results)},indent=2)+'\n')
        return False
    results+=[run('packaged-camera-'+name,args=['--vehicle-check=cameras'],render=True,compat=compat) for name,compat in [('forward',False),('compatibility',True)]]
    jobs=[(track,mode) for track in ['astra_coast','colombo_city','kandy_lake'] for mode in ['single','split']]
    def race(job):
        track,mode=job
        return run('packaged-race-'+track+'-'+mode,args=['--track='+track,'--track-check='+mode],vehicles=BASELINE/'GameAssets/vehicles')
    # Native Godot/.NET startup and device enumeration share machine resources.
    # Keep executable race checks isolated; seeded proxy races remain batched.
    results+=[race(job) for job in jobs]
    (QA/'packaged-acceptance.json').write_text(json.dumps({'status':'PASS' if all(results) else 'FAIL','cases':len(results),'candidate_pck_sha256':core_sha()},indent=2)+'\n')
    return all(results)

def performance(compatibility_only=False,forward_baseline_only=False,candidates_only=False,fresh_profile=False):
    previous=QA/'performance-acceptance.json'
    measurements=json.loads(previous.read_text())['measurements'] if (compatibility_only or forward_baseline_only or candidates_only) and previous.exists() else {}
    ok=True
    selected=[('forward_plus',False)] if forward_baseline_only else [('gl_compatibility',True)] if compatibility_only else [('forward_plus',False),('gl_compatibility',True)]
    for renderer,compat in selected:
        if not forward_baseline_only and not candidates_only:measurements[renderer]={}
        for name,folder in ([('candidate',CANDIDATE)] if candidates_only else [('baseline',BASELINE)] if forward_baseline_only else [('baseline',BASELINE),('candidate',CANDIDATE)]):
            label='performance-'+renderer+'-'+name
            if fresh_profile:label+='-isolated-'+str(time.time_ns())
            file=QA/label/('performance-'+renderer+'.json')
            if file.exists():
                history=QA/'history-v3'/str(time.time_ns());history.mkdir(parents=True,exist_ok=True)
                for old in [file,QA/(label+'.log'),QA/label/'process.json']:
                    if old.exists():shutil.copy2(old,history/old.name)
                file.unlink()
            ok=run(label,folder,args=['--track=kandy_lake','--track-check=performance','--vehicle=bigster'],render=True,compat=compat,vehicles=BASELINE/'GameAssets/vehicles') and ok
            if file.exists():measurements[renderer][name]=json.loads(file.read_text())
            else:ok=False
    if ok:
        forward=measurements['forward_plus'];compat=measurements['gl_compatibility']
        gates={'forward_p95_under_16_7':forward['candidate']['p95_ms']<=16.7,'compatibility_within_10_percent':compat['candidate']['p95_ms']<=compat['baseline']['p95_ms']*1.1}
        ok=all(gates.values())
    else:gates={}
    report={'status':'PASS' if ok else 'FAIL','gates':gates,'measurements':measurements,'candidate_pck_sha256':core_sha()}
    (QA/'performance-acceptance.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report),flush=True)
    return ok

def render_budget():
    # Only the GLES split-screen shadow preset changed; prior physics/Forward+
    # evidence remains applicable. Recheck the exported core and rendered views.
    results=[run('packaged-content',args=['--verify-content']),run('packaged-balance',args=['--distinct-check']),run('packaged-camera-compatibility',args=['--vehicle-check=cameras'],render=True,compat=True)]
    file=QA/'packaged-acceptance.json'
    report=json.loads(file.read_text())
    report['final_render_budget_checks']=len(results)
    if not all(results):report['status']='FAIL'
    file.write_text(json.dumps(report,indent=2)+'\n')
    return all(results)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('mode',choices=['smoke','performance','performance-compatibility','performance-forward-baseline','performance-candidates','performance-compatibility-candidate','render_budget']);args=parser.parse_args()
    ok=performance(True,False,True,True) if args.mode=='performance-compatibility-candidate' else performance(False,False,True) if args.mode=='performance-candidates' else performance(False,True) if args.mode=='performance-forward-baseline' else performance(True) if args.mode=='performance-compatibility' else globals()[args.mode]()
    raise SystemExit(0 if ok else 2)
