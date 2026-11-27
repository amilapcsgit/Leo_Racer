"""Compare isolated 2.7.1 and 2.7.8 exports with one shared wall-clock probe."""
from pathlib import Path
import argparse, json, os, shutil, subprocess, time
import city_packs
from package_ultra import ROOT, BASE, QA, sha

def prepare(version):
    source={'2.7.8':BASE,'2.7.1':ROOT/'build/Release-2.7.1-Ultra','2.7.8-previous':ROOT/'build/preserved-candidate-278-before-live-feedback'}[version]
    target=QA/'benchmark-copies'/version
    def link(src,dst):
        try:os.link(src,dst)
        except OSError:shutil.copy2(src,dst)
        return str(dst)
    if not target.exists():shutil.copytree(source,target,copy_function=link,ignore=shutil.ignore_patterns('LeoRacer.pck','QA','*.log'))
    engine,entries=city_packs.read_pack(source/'LeoRacer.pck')
    adapter='''extends Node
var root: Window:
 get:return get_tree().root
var process_frame: Signal:
 get:return get_tree().process_frame
func _ready() -> void:_initialize()
func quit(code: int=0) -> void:get_tree().quit(code)
'''
    probe=(ROOT/'tests/release278_performance.gd').read_text(encoding='utf-8').replace('extends SceneTree',adapter,1)
    key='tests/native270/visual.gd';entries.pop(key+'.remap',None);entries[key]=probe.expandtabs(4).encode('utf-8')
    city_packs.write_pack(target/'LeoRacer.pck',engine,entries)
    return target

def run(version,compat):
    target=prepare(version)
    label=version+'-'+('compatibility' if compat else 'forward')
    output=QA/'performance'/label
    if (output/'performance.json').exists():raise RuntimeError('Preserve completed measurements: '+label)
    output.mkdir(parents=True,exist_ok=True);profile=output/'profile';profile.mkdir(exist_ok=True)
    env=dict(os.environ,APPDATA=str(profile),LOCALAPPDATA=str(profile),DOTNET_ROOT=str(profile/'no-sdk'),LEO_ASSET_ROOT=str(target/'GameAssets'))
    args=[str(target/'LeoRacer.console.exe'),'--position','-3200,-3200']
    if compat:args+=['--rendering-method','gl_compatibility','--rendering-driver','opengl3']
    args+=['--','--drive-test','--ultra-check=visual','--track=astra_coast','--vehicles='+str(target/'GameAssets/vehicles'),'--tracks='+str(target/'GameAssets/tracks'),'--qa-output='+str(output)]
    if version=='2.7.1':args+=['--baseline271']
    if version=='2.7.8-previous':args+=['--cockpit-only']
    began=time.monotonic()
    with (output/'process.log').open('w',encoding='utf-8') as log:
        process=subprocess.Popen(args,cwd=target,env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW|subprocess.NORMAL_PRIORITY_CLASS)
        while process.poll() is None:
            time.sleep(.5)
            current=(output/'process.log').read_text(encoding='utf-8',errors='replace')
            if 'SCRIPT ERROR' in current or 'Parse Error' in current or time.monotonic()-began>600:process.kill();break
        code=process.wait()
    text=(output/'process.log').read_text(encoding='utf-8',errors='replace')
    report={'exit_code':code,'seconds':round(time.monotonic()-began,2),'source_core_sha256':sha(({'2.7.8':BASE,'2.7.1':ROOT/'build/Release-2.7.1-Ultra','2.7.8-previous':ROOT/'build/preserved-candidate-278-before-live-feedback'}[version])/'LeoRacer.pck'),'errors':[line for line in text.splitlines() if 'SCRIPT ERROR' in line or 'Parse Error' in line]}
    (output/'process.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    if code or report['errors'] or not (output/'performance.json').exists():raise RuntimeError('Benchmark failed: '+label+'\n'+text[-3000:])
    print('BENCHMARK278',label,json.dumps(report),flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--version',choices=['2.7.1','2.7.8','2.7.8-previous']);parser.add_argument('--compatibility',action='store_true');args=parser.parse_args()
    if args.version:run(args.version,args.compatibility)
    else:
        for compat in [False,True]:
            for version in ['2.7.1','2.7.8','2.7.8-previous']:run(version,compat)
