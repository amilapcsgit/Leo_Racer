"""Run source/export checks with isolated profiles, real exits, and retained logs."""
from pathlib import Path
import argparse, json, os, re, subprocess, time
from stage_ultra_content import ROOT, sha
TESTS={
    'ui':('tests/release26_ui_test.gd','--release-ui-check'),
    'polish':('tests/release26_polish_test.gd','--release-polish-check'),
    'content':('tests/release260_content_test.gd','--release-content-check'),
    'garage':('tests/release260_runtime_test.gd',None),
    'previews':('tests/ultra_preview_test.gd',None),
    'impact':('tests/lighting_world_test.gd',None),
    'core':('tests/ultra_core_test.gd',None),
    'visual':('tests/ultra_visual_test.gd',None),
    'physics':('tests/ultra_physics_test.gd',None),
    'contacts':('tests/release260_collision_test.gd',None),
    'audit':('tests/release260_collision_test.gd',None),
}
def run(kind,compat=False,export=None,extra=()):
    if export:export=Path(export).resolve()
    renderer='compatibility' if compat else 'forward'
    label=('export-' if export else 'source-')+kind+'-'+renderer
    out=ROOT/'build/qa270'/label;out.mkdir(parents=True,exist_ok=True)
    profile=out/'profile';profile.mkdir(exist_ok=True)
    env=os.environ.copy();env.update(APPDATA=str(profile),LOCALAPPDATA=str(profile))
    assets=Path(export)/'GameAssets' if export else ROOT/'build/content-baseline/GameAssets'
    env['LEO_ASSET_ROOT']=str(assets)
    script,switch=TESTS[kind]
    if export:
        command=[str(Path(export)/'LeoRacer.console.exe')]
        env['DOTNET_ROOT']=str(profile/'no-sdk')
        env['PATH']=os.pathsep.join(p for p in env['PATH'].split(os.pathsep) if not any(word in p.lower() for word in ['dotnet','.tools']))
        # Native template probes enter through the opt-in bootstrap path.
    else:
        engine=ROOT/'.tools/godot/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe'
        if not engine.exists():engine=ROOT.parent.parent/'tools/godot-net/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe'
        sdk=ROOT/'.tools/dotnet'
        if not sdk.exists():sdk=ROOT.parent.parent/'tools/dotnet'
        env['DOTNET_ROOT']=str(sdk);env['PATH']=str(sdk)+os.pathsep+env['PATH']
        command=[str(engine),'--path',str(ROOT),'--script','res://'+script]
    render=kind in ['ui','polish','garage','visual','previews','impact']
    command+=['--position','-3200,-3200'] if render else ['--headless']
    if compat:command+=['--rendering-method','gl_compatibility','--rendering-driver','opengl3']
    command+=['--','--drive-test','--track=astra_coast','--vehicles='+str(assets/'vehicles'),'--tracks='+str(assets/'tracks'),'--qa-output='+str(out)]
    if export:command.append(switch if switch else '--ultra-check='+kind)
    if kind in ['contacts','audit']:command.append('--quality25-mode='+kind)
    if kind=='garage':command.append('--no-captures')
    if kind=='impact':command.append('--impact-only')
    command.extend(extra)
    started=time.monotonic()
    with (out/'process.log').open('w',encoding='utf-8') as log:
        process=subprocess.Popen(command,cwd=Path(export) if export else ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        code=None
        while process.poll() is None:
            time.sleep(.5)
            current=(out/'process.log').read_text(encoding='utf-8',errors='replace')
            if any(term in current for term in ['SCRIPT ERROR','Parse Error','Corrupted header']) or time.monotonic()-started>1800:
                if os.name=='nt':subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
                else:process.kill()
                code=-998;break
        actual=process.wait()
        if code is None:code=actual
    text=(out/'process.log').read_text(encoding='utf-8',errors='replace')
    errors=[line for line in text.splitlines() if any(term in line for term in ['SCRIPT ERROR','Parse Error','Shader compilation failed','CONTENT_VALIDATION_FAILED','CrashHandlerException','Corrupted header',"Couldn't load project data"])]
    failed=bool(re.search(r'"status"\s*:\s*"FAIL"',text))
    if not re.search(r'"status"\s*:\s*"PASS"',text):errors.append('Expected test PASS report missing')
    warnings=[line for line in text.splitlines() if any(term in line for term in ['leaked','resources still in use','Pages in use'])]
    report={'status':'PASS' if code==0 and not errors and not failed else 'FAIL','exit_code':code,'seconds':round(time.monotonic()-started,2),'errors':errors,'shutdown_warnings':warnings,'sdk_removed':bool(export)}
    if export:report['core_sha256']=sha(Path(export)/'LeoRacer.pck')
    (out/'process.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('ULTRA_CHECK',label,json.dumps(report),flush=True)
    if report['status']!='PASS':print('\n'.join(text.splitlines()[-25:]),flush=True)
    return report['status']=='PASS'
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('kind',choices=TESTS);parser.add_argument('--compatibility',action='store_true');parser.add_argument('--export',type=Path);args,extra=parser.parse_known_args()
    raise SystemExit(0 if run(args.kind,args.compatibility,args.export,extra) else 1)
