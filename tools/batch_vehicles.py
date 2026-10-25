"""Resumable local car authoring; wraps the existing Workshop and optimizer.

Supplied models and generated folders stay outside version control. No game
executable export, driver import, driver fit or driver validation is performed.
"""
from __future__ import annotations
import argparse, concurrent.futures, hashlib, json, os, re, shutil, subprocess, time, zipfile,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'build/batch-cars'

def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def write(p,data):
    p=Path(p);p.parent.mkdir(parents=True,exist_ok=True)
    temporary=p.with_suffix(p.suffix+'.tmp');temporary.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8');temporary.replace(p)
def sha(p):
    with Path(p).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def engine():
    candidates=[ROOT/'.tools/godot/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe',ROOT.parent.parent/'tools/godot-net/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe']
    return next(p for p in candidates if p.is_file())
def environment(key):
    env=os.environ.copy();sdk=ROOT/'.tools/dotnet'
    if not (sdk/'dotnet.exe').is_file():sdk=ROOT.parent.parent/'tools/dotnet'
    env['DOTNET_ROOT']=str(sdk);env['PATH']=str(sdk)+os.pathsep+env.get('PATH','')
    env['APPDATA']=str(WORK/'user-data'/key);Path(env['APPDATA']).mkdir(parents=True,exist_ok=True)
    env['DOTNET_CLI_TELEMETRY_OPTOUT']='1'
    return env
def godot(job,render=False):
    key=job.get('id','batch');suffix=job.get('mode','convert')
    directory=WORK/key;directory.mkdir(parents=True,exist_ok=True)
    jobfile=directory/(suffix+'-job.json');report=directory/(suffix+'-report.json')
    job['report']=str(report);write(jobfile,job)
    command=[str(engine()),'--path',str(ROOT)]
    command+=['--rendering-method','gl_compatibility','--rendering-driver','opengl3'] if render else ['--headless']
    command+=['--script','res://tools/batch_vehicle.gd','--quit-after','24000','--','--drive-test','--job='+str(jobfile)]
    with (directory/(suffix+'.log')).open('w',encoding='utf-8') as log:
        result=subprocess.run(command,cwd=ROOT,env=environment(key),stdout=log,stderr=subprocess.STDOUT,timeout=300)
    if report.is_file():return read(report)
    return {'ok':False,'error':'Godot exited without report: '+str(result.returncode),'log':str(directory/(suffix+'.log'))}
def inventory(source):
    return [{'source':str(p),'filename':p.name,'id':('import_'+re.sub('[^a-z0-9]+','_',p.stem.lower()).strip('_'))[:64],
             'source_hash':sha(p),'source_bytes':p.stat().st_size,'display_name':p.stem.replace('_',' ').replace('-',' ')} for p in sorted(source.glob('*.glb'))]
def prepare(item,profiles):
    profile=profiles.get(item['filename'],{})
    signature=hashlib.sha256((item['source_hash']+json.dumps(profile,sort_keys=True)+'batch-1').encode()).hexdigest()[:12]
    directory=WORK/item['id'];output=directory/('converted-'+signature)
    progress=directory/'progress.json'
    if progress.is_file():
        old=read(progress)
        if old.get('signature')==signature and old.get('converted',{}).get('ok') and output.is_dir():return old
    job={**item,**profile,'output':str(output),'preview':str(directory/'needs-setup.glb')}
    with Path(item['source']).open('rb') as f:
        header=f.read(20);length=struct.unpack('<5I',header)[3];document=json.loads(f.read(length))
        nontri=sum(p.get('mode',4)!=4 for m in document.get('meshes',[]) for p in m.get('primitives',[]))
        if nontri:
            tail=f.read();empty=set()
            for index,mesh in enumerate(document.get('meshes',[])):
                mesh['primitives']=[p for p in mesh.get('primitives',[]) if p.get('mode',4)==4]
                if not mesh['primitives']:empty.add(index)
            for node in document.get('nodes',[]):
                if node.get('mesh') in empty:node.pop('mesh')
            # Empty unused meshes still need valid schema objects. Keep them out
            # of the mesh table and remap all referenced mesh indices.
            remap={i:n for n,i in enumerate(i for i in range(len(document.get('meshes',[]))) if i not in empty)}
            document['meshes']=[m for i,m in enumerate(document.get('meshes',[])) if i not in empty]
            for node in document.get('nodes',[]):
                if 'mesh' in node:node['mesh']=remap[node['mesh']]
            data=json.dumps(document,separators=(',',':')).encode();data+=b' '*(-len(data)%4)
            directory.mkdir(parents=True,exist_ok=True);clean=directory/'triangles-only.glb'
            clean.write_bytes(struct.pack('<5I',0x46546c67,2,20+len(data)+len(tail),len(data),0x4e4f534a)+data+tail)
            job['source_model']=str(clean)
    if output.is_dir():
        result={'ok':True,'folder':str(output),'recovered_complete_folder':True}
    else:result=godot(job)
    state={**item,'signature':signature,'converted':result,'output':str(output),'updated':time.time()};write(progress,state)
    print(('READY ' if result.get('ok') else 'NEEDS SETUP ')+item['filename'],flush=True)
    return state
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase',choices=['prepare','render','optimize','textures','validate','install','report','sheets'])
    parser.add_argument('--source',type=Path,required=True);parser.add_argument('--profiles',type=Path,default=WORK/'profiles.json')
    parser.add_argument('--destination',type=Path,default=ROOT/'build/CustomCars-dev/GameAssets/vehicles')
    parser.add_argument('--workers',type=int,default=2);parser.add_argument('--only',default='')
    args=parser.parse_args();WORK.mkdir(parents=True,exist_ok=True)
    baseline=WORK/'game-baseline.json'
    game=args.destination.resolve().parents[1]
    if not baseline.exists() and (game/'LeoRacer.exe').is_file():
        write(baseline,{'core':{n:sha(game/n) for n in ['LeoRacer.exe','LeoRacer.pck']},'stock':{p.relative_to(args.destination).as_posix():sha(p) for p in args.destination.rglob('*') if p.is_file()}})
    items=inventory(args.source);write(WORK/'inventory.json',items)
    profiles=read(args.profiles) if args.profiles.is_file() else {}
    if args.only:items=[v for v in items if args.only in v['filename']]
    if args.phase=='prepare':
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:list(pool.map(lambda v:prepare(v,profiles),items))
    elif args.phase=='render':
        for item in items:
            state=read(WORK/item['id']/'progress.json');converted=state['converted'];folder=Path(state['output'])
            model=folder/'model.glb' if converted.get('ok') else WORK/item['id']/'needs-setup.glb'
            if not model.is_file():continue
            prefix=WORK/'previews'/item['id'];prefix.parent.mkdir(parents=True,exist_ok=True)
            image=prefix.with_name(prefix.name+'-front.png')
            if not image.is_file() or image.stat().st_mtime<model.stat().st_mtime:godot({'id':item['id'],'mode':'render','model':str(model),'prefix':str(prefix)},True)
    elif args.phase=='optimize':
        blender=Path('C:/Program Files/Blender Foundation/Blender 4.5/blender.exe')
        for item in items:
            progress=WORK/item['id']/'progress.json';state=read(progress)
            if not state['converted'].get('ok') or state.get('optimized'):continue
            folder=Path(state['output']);job={'folder':str(folder),'budget':200000,'maximum_texture':2048}
            jobfile=WORK/item['id']/'optimize-job.json';write(jobfile,job)
            with (WORK/item['id']/'optimize.log').open('w',encoding='utf-8') as log:
                result=subprocess.run([str(blender),'--background','--factory-startup','--python',str(ROOT/'blender/batch_vehicle_optimize.py'),'--','--job',str(jobfile)],stdout=log,stderr=subprocess.STDOUT,timeout=300)
            report=folder/'optimization-report.json'
            if result.returncode or not report.is_file():state['optimization_error']='See optimize.log'
            else:state['optimized']=read(report)
            write(progress,state);print('OPTIMIZE '+item['filename'],flush=True)
    elif args.phase=='textures':
        def textures(item):
            progress=WORK/item['id']/'progress.json';state=read(progress)
            if not state.get('optimized'):return
            folder=Path(state['output']);signature=sha(folder/'model.glb');metadata=folder/'optimized-textures.json'
            if metadata.is_file() and read(metadata).get('source_hash')==signature:return
            command=[str(engine()),'--headless','--path',str(ROOT),'--script','res://tools/optimize_vehicle.gd','--','--drive-test','--vehicle-folder='+str(folder),'--max-texture=2048']
            with (WORK/item['id']/'textures.log').open('w',encoding='utf-8') as log:
                result=subprocess.run(command,env=environment(item['id']),stdout=log,stderr=subprocess.STDOUT,timeout=300,cwd=ROOT)
            state['textures']={'ok':result.returncode==0 and metadata.is_file(),'source_hash':signature};write(progress,state)
            print('TEXTURES '+item['filename']+' '+str(state['textures']['ok']),flush=True)
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:list(pool.map(textures,items))
    elif args.phase=='sheets':
        from PIL import Image,ImageDraw,ImageFont
        font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
        for page in range((len(items)+7)//8):
            image=Image.new('RGB',(1440,1160),'#111b2a');draw=ImageDraw.Draw(image)
            for index,item in enumerate(items[page*8:page*8+8]):
                x=(index%2)*720;y=(index//2)*290
                draw.text((x+8,y+4),item['filename'][:65],fill='white',font=font)
                for side_index,side in enumerate(['front','rear']):
                    p=WORK/'previews'/(item['id']+'-'+side+'.png')
                    if p.is_file():
                        preview=Image.open(p).convert('RGB');preview.thumbnail((355,250));image.paste(preview,(x+side_index*360,y+30))
                    draw.text((x+side_index*360+8,y+265),'Canonical '+side,fill='#50dde3',font=font)
            target=WORK/'previews'/('sheet-%d.jpg'%(page+1));image.save(target,quality=92);print(target)
    elif args.phase=='validate':
        def validate(item):
            progress=WORK/item['id']/'progress.json';state=read(progress)
            if not state['converted'].get('ok'):return
            state['validation']=godot({'id':item['id'],'mode':'validate','folder':state['output']});write(progress,state)
            print('VALIDATE '+item['filename']+' '+str(state['validation'].get('ok')),flush=True)
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:list(pool.map(validate,items))
    elif args.phase=='install':
        args.destination.mkdir(parents=True,exist_ok=True)
        for item in items:
            progress=WORK/item['id']/'progress.json';state=read(progress)
            if not state.get('validation',{}).get('ok'):continue
            source=Path(state['output']);destination=args.destination/item['id']
            digest=sha(source/'model.glb')
            if destination.exists():
                if not (destination/'model.glb').is_file() or sha(destination/'model.glb')!=digest:raise RuntimeError('Protected existing folder: '+str(destination))
            else:
                staging=args.destination.parent/'.batch-staging'/item['id'];staging.parent.mkdir(parents=True,exist_ok=True)
                if staging.exists():raise RuntimeError('Staging requires review: '+str(staging))
                shutil.copytree(source,staging);staging.rename(destination)
            state['installed']=str(destination);write(progress,state)
        build_report(items,args.destination)
    else:build_report(items,args.destination)

def build_report(items,destination):
    rows=[]
    for item in items:
        progress=WORK/item['id']/'progress.json';state=read(progress) if progress.is_file() else item
        rows.append({k:v for k,v in state.items() if k!='converted'}|{'conversion_ok':state.get('converted',{}).get('ok',False),'conversion_error':state.get('converted',{}).get('error','')})
    report={'format':1,'offline':True,'driver_tests':0,'cars':rows,'installed':sum('installed' in r for r in rows),'source_files':len(rows),'sources_unchanged':all(sha(i['source'])==i['source_hash'] for i in items)}
    write(WORK/'batch-report.json',report);print(json.dumps({k:v for k,v in report.items() if k!='cars'},indent=2))

if __name__=='__main__':main()
