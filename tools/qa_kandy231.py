"""Run a Godot diagnostic with explicit user arguments and an isolated profile."""
from pathlib import Path
import argparse,subprocess,os,json
ROOT=Path(__file__).resolve().parents[1]
def run(script,label,args=(),headless=True,compat=False,project=ROOT,mono=True):
    engine=ROOT.parent.parent/('tools/godot-net/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe' if mono else 'tools/godot/Godot_v4.7.2-stable_win64_console.exe')
    env=os.environ.copy();work=ROOT/'build/kandy231';work.mkdir(parents=True,exist_ok=True)
    for key,name in [('APPDATA','profiles/'+label),('LOCALAPPDATA','profiles/'+label),('TEMP','temp'),('TMP','temp')]:
        path=work/name;path.mkdir(parents=True,exist_ok=True);env[key]=str(path)
    env['DOTNET_ROOT']=str(ROOT.parent.parent/'tools/dotnet');env['PATH']=env['DOTNET_ROOT']+os.pathsep+env['PATH']
    cmd=[str(engine),'--path',str(project)]
    if headless:cmd+=['--headless']
    if compat:cmd+=['--rendering-method','gl_compatibility','--rendering-driver','opengl3']
    cmd+=['--script',script,'--','--drive-test',*args]
    process=subprocess.run(cmd,env=env,cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=600)
    log=process.stdout+process.stderr;(work/(label+'.log')).write_text(log,encoding='utf-8')
    errors=[line for line in log.splitlines() if any(marker in line for marker in ['SCRIPT ERROR','Parse Error','Shader compilation failed','Failed loading resource:',"Can't load dependency:"])]
    print(json.dumps({'label':label,'exit_code':process.returncode,'errors':errors,'log':str(work/(label+'.log'))}),flush=True)
    return process.returncode==0 and not errors
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('script');p.add_argument('label');p.add_argument('--render',action='store_true');p.add_argument('--compat',action='store_true');p.add_argument('--sdk',action='store_true');p.add_argument('args',nargs=argparse.REMAINDER);a=p.parse_args()
    import sys
    sys.exit(0 if run(a.script,a.label,a.args,not a.render,a.compat,ROOT/'build/TrackSDK' if a.sdk else ROOT,not a.sdk) else 2)
