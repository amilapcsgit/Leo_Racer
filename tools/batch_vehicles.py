"""Resumable local car authoring; wraps the existing Workshop and optimizer.

Supplied models and generated folders stay outside version control. No game
executable export, driver import, driver fit or driver validation is performed.
"""
from __future__ import annotations
import argparse, concurrent.futures, hashlib, json, math, os, re, shutil, subprocess, time, zipfile,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'build/batch-cars'

def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def write(p,data):
    p=Path(p);p.parent.mkdir(parents=True,exist_ok=True)
    temporary=p.with_suffix(p.suffix+'.tmp');temporary.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8');temporary.replace(p)
def sha(p):
    with Path(p).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def install_folder(source,destination,previous=None):
    """Stage complete folders without overwriting an existing content ID."""
    destination.parent.mkdir(parents=True,exist_ok=True)
    if destination.exists():
        if all((destination/p.relative_to(source)).is_file() and sha(destination/p.relative_to(source))==sha(p) for p in source.rglob('*') if p.is_file()):return
        actual={p.relative_to(destination).as_posix():sha(p) for p in destination.rglob('*') if p.is_file()}
        if not previous or actual!=previous:raise RuntimeError('Protected existing folder: '+str(destination))
    staging=destination.parent.parent/'.batch-staging'/destination.name;staging.parent.mkdir(parents=True,exist_ok=True)
    if staging.exists():raise RuntimeError('Staging requires review: '+str(staging))
    shutil.copytree(source,staging)
    backup=WORK/'installed-backups'/(destination.name+'-'+str(time.time_ns()))
    if destination.exists():
        # Both resolved move targets are checked inside this workspace before
        # moving our fingerprint-matching previous batch revision.
        if not destination.resolve().is_relative_to(ROOT) or not backup.resolve().is_relative_to(WORK):raise RuntimeError('Unsafe revision move')
        backup.parent.mkdir(parents=True,exist_ok=True);destination.rename(backup)
    try:staging.rename(destination)
    except Exception:
        if backup.exists():backup.rename(destination)
        raise
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
    if report.exists():report.unlink()
    job['report']=str(report);write(jobfile,job)
    command=[str(engine()),'--path',str(ROOT)]
    command+=['--rendering-method','gl_compatibility','--rendering-driver','opengl3'] if render else ['--headless']
    command+=['--script','res://tools/batch_vehicle.gd','--quit-after','24000','--','--drive-test','--job='+str(jobfile)]
    with (directory/(suffix+'.log')).open('w',encoding='utf-8') as log:
        result=subprocess.run(command,cwd=ROOT,env=environment(key),stdout=log,stderr=subprocess.STDOUT,timeout=300)
    if report.is_file():
        value=read(report)
        if result.returncode:value['ok']=False;value['process_exit']=result.returncode
        return value
    return {'ok':False,'error':'Godot exited without report: '+str(result.returncode),'log':str(directory/(suffix+'.log'))}
def inventory(source):
    return [{'source':str(p),'filename':p.name,'id':('import_'+re.sub('[^a-z0-9]+','_',p.stem.lower()).strip('_'))[:64],
             'source_hash':sha(p),'source_bytes':p.stat().st_size,'display_name':p.stem.replace('_',' ').replace('-',' ')} for p in sorted(source.glob('*.glb'))]
def prepare(item,profiles):
    profile=profiles.get(item['filename'],{})
    if profile.get('source_sha256',item['source_hash'])!=item['source_hash']:raise RuntimeError('Reviewed selections belong to a different source: '+item['filename'])
    parameters={k:v for k,v in profile.items() if k!='source_sha256'}
    signature=hashlib.sha256((item['source_hash']+json.dumps(parameters,sort_keys=True)+'batch-1').encode()).hexdigest()[:12]
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
    state={**item,'signature':signature,'converted':result,'output':str(output),'updated':time.time()}
    if progress.is_file():
        old=read(progress)
        for field in ['installed','installed_files']:
            if field in old:state[field]=old[field]
    write(progress,state)
    print(('READY ' if result.get('ok') else 'NEEDS SETUP ')+item['filename'],flush=True)
    return state
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase',choices=['audit','prepare','render','optimize','textures','facing','validate','install','report','sheets','drive','package'])
    parser.add_argument('--source',type=Path,required=True);parser.add_argument('--profiles',type=Path,default=WORK/'profiles.json' if (WORK/'profiles.json').is_file() else ROOT/'tools/car_collection_profiles.json')
    parser.add_argument('--destination',type=Path,default=ROOT/'build/CustomCars-dev/GameAssets/vehicles')
    parser.add_argument('--workers',type=int,default=2);parser.add_argument('--only',default='')
    parser.add_argument('--reuse-folder',type=Path,help='Already prepared folder, validated before installation')
    args=parser.parse_args();WORK.mkdir(parents=True,exist_ok=True)
    baseline=WORK/'game-baseline.json'
    game=args.destination.resolve().parents[1]
    if not baseline.exists() and (game/'LeoRacer.exe').is_file():
        write(baseline,{'core':{n:sha(game/n) for n in ['LeoRacer.exe','LeoRacer.pck']},'stock':{p.relative_to(args.destination).as_posix():sha(p) for p in args.destination.rglob('*') if p.is_file()}})
    items=inventory(args.source);write(WORK/'inventory.json',items)
    profiles=read(args.profiles) if args.profiles.is_file() else {}
    if args.only:items=[v for v in items if args.only in v['filename']]
    if args.phase=='audit':
        # Reviewed geometry selections supplement name-based suggestions. Only
        # whole islands inside an existing tyre envelope are selected; body
        # sheets, wheel arches and remote spare tyres are never sliced here.
        changes=[]
        for item in items:
            progress=WORK/item['id']/'progress.json';state=read(progress);report=state['converted']
            folder=args.destination/item['id']
            if folder.is_dir() and 'installed_files' not in state:
                state['installed_files']={p.relative_to(folder).as_posix():sha(p) for p in folder.rglob('*') if p.is_file()};write(progress,state)
            parts=report['inventory'];lookup={p['id']:p for p in parts}
            groups=[list(g) for g in report['suggestions']];fixed=[list(g) for g in report['calipers']]
            used={key for group in groups+fixed for key in group};centers=[];bounds=[]
            for group in groups:
                members=[lookup[k] for k in group]
                low=[min(p['center'][i]-p['size'][i]/2 for p in members) for i in range(3)]
                high=[max(p['center'][i]+p['size'][i]/2 for p in members) for i in range(3)]
                centers.append([(low[i]+high[i])/2 for i in range(3)]);bounds.append((low,high))
            additions=0
            for part in parts:
                name=part['name'].lower()
                if 'spare' in name:continue
                center=part['center'];size=part['size'];slot=min(range(4),key=lambda j:sum((center[i]-centers[j][i])**2 for i in range(3)))
                c=centers[slot];low,high=bounds[slot];radius=max(high[1]-low[1],high[2]-low[2])/2
                dx=abs(center[0]-c[0]);radial=math.hypot(center[1]-c[1],center[2]-c[2])
                if ('calliper' in name or 'caliper' in name) and dx<radius and radial<radius*1.2:
                    for g in groups+fixed:
                        if part['id'] in g:g.remove(part['id'])
                    fixed[slot].append(part['id']);additions+=1;continue
                if part['id'] in used:continue
                circular=min(size[1:])>.15 and .75<size[1]/size[2]<1.33 and size[0]<max(size[1:])*.7 and dx<radius*.65 and radial<radius*.25 and max(size[1:])<radius*4
                contained=all(center[i]-size[i]/2>=low[i]-.008 and center[i]+size[i]/2<=high[i]+.008 for i in range(3))
                if circular or contained:groups[slot].append(part['id']);additions+=1
            for slot,keys in enumerate(profiles.get(item['filename'],{}).get('stationary_additions',[])):
                for key in keys:
                    if key not in lookup:raise RuntimeError('Guided caliper selection no longer matches source')
                    for group in groups+fixed:
                        if key in group:group.remove(key)
                    fixed[slot].append(key);additions+=1
            if additions:
                profile=profiles.setdefault(item['filename'],{});profile['wheel_groups']=groups;profile['caliper_groups']=fixed
                changes.append({'filename':item['filename'],'reviewed_additions':additions,'wheel_parts':[len(g) for g in groups],'caliper_parts':[len(g) for g in fixed]})
        write(args.profiles,profiles);write(WORK/'wheel-audit.json',changes);print(json.dumps(changes,indent=2))
    elif args.phase=='prepare':
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:list(pool.map(lambda v:prepare(v,profiles),items))
    elif args.phase=='render':
        def render(item):
            state=read(WORK/item['id']/'progress.json');converted=state['converted'];folder=Path(state['output'])
            model=folder/'model.glb' if converted.get('ok') else WORK/item['id']/'needs-setup.glb'
            if not model.is_file():return
            prefix=WORK/'previews'/item['id'];prefix.parent.mkdir(parents=True,exist_ok=True)
            image=prefix.with_name(prefix.name+'-front.png')
            metadata=folder/'vehicle.json'
            if not image.is_file() or image.stat().st_mtime<max(model.stat().st_mtime,metadata.stat().st_mtime if metadata.is_file() else 0):
                job={'id':item['id'],'mode':'render','model':str(model),'prefix':str(prefix)}
                if converted.get('ok'):job['vehicle_folder']=str(folder)
                result=godot(job,True)
                if not result.get('ok'):raise RuntimeError('Preview failed: '+str(result))
            if converted.get('ok') and image.is_file():shutil.copy2(image,folder/'thumbnail.png')
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:list(pool.map(render,items))
    elif args.phase=='facing':
        facing=read(WORK/'facing.json' if (WORK/'facing.json').is_file() else ROOT/'tools/car_collection_facing.json')
        for item in items:
            progress=WORK/item['id']/'progress.json';state=read(progress)
            if not state['converted'].get('ok'):continue
            angle=facing[item['filename']]
            if state.get('facing_angle')==angle:continue
            folder=Path(state['output']);metadata=folder/'vehicle.json';base=folder.parent/(folder.name+'-base-definition.json')
            if not base.is_file():write(base,read(metadata))
            data=read(base)
            if angle==180:
                data['normalization']={'basis':[[-1,0,0],[0,1,0],[0,0,-1]],'origin':[0,0,0]}
                for key in ['collision_position','preview_target']:
                    v=data[key];data[key]=[-v[0],v[1],-v[2]]
                data['wheels']=[data['wheels'][i] for i in [3,2,1,0]]
                for i,wheel in enumerate(data['wheels']):wheel['steering']=i<2;wheel['axle']=[-1,0,0]
            elif angle!=0:raise ValueError('Facing correction must be 0 or 180 degrees')
            c=data['collision_position'];s=data['collision_size']
            data['exhausts']=[[c[0]-s[0]*.28,max(.2,c[1]-s[1]*.25),c[2]+s[2]*.5+.08],[c[0]+s[0]*.28,max(.2,c[1]-s[1]*.25),c[2]+s[2]*.5+.08]]
            write(metadata,data);state['facing_angle']=angle;state.pop('validation',None);write(progress,state)
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
            if state['source_hash']!=item['source_hash']:raise RuntimeError('Changed source requires prepare: '+item['filename'])
            if not state.get('optimized',{}).get('target_met') or not state.get('textures',{}).get('ok') or 'facing_angle' not in state:raise RuntimeError('Complete optimization, textures and facing before installation: '+item['filename'])
            source=Path(state['output']);destination=args.destination/item['id']
            report=read(source/'conversion-report.json')
            report.setdefault('inspected_source_sha256',report.get('source_sha256'))
            report.update({'source_sha256':item['source_hash'],'source_filename':item['filename'],'final_model_sha256':sha(source/'model.glb'),'final_triangles':state['optimized']['triangles_after'],'maximum_texture':2048,'facing_correction_degrees':state['facing_angle'],'runtime_validation':state['validation'],'modded':True,'ranked':False})
            write(source/'conversion-report.json',report)
            install_folder(source,destination,state.get('installed_files'))
            state['installed']=str(destination);state['installed_files']={p.relative_to(destination).as_posix():sha(p) for p in destination.rglob('*') if p.is_file()};write(progress,state)
        if args.reuse_folder:
            source=args.reuse_folder.resolve();data=read(source/'vehicle.json')
            result=godot({'id':'reused_'+data['id'],'mode':'validate','folder':str(source)})
            if not result.get('ok'):raise RuntimeError('Prepared vehicle validation failed: '+str(result))
            destination=args.destination/data['id'];install_folder(source,destination)
            write(WORK/'reused.json',{'id':data['id'],'folder':str(destination),'model_hash':sha(source/'model.glb'),'validation':result})
        build_report(items,args.destination)
    elif args.phase=='drive':
        # The exported game's private proving ground does not create a race or
        # ranking store. It exercises actual acceleration, wheels and boost.
        results=[];game=args.destination.resolve().parents[1]
        for item in items:
            folder=args.destination/item['id']
            if not folder.is_dir():raise RuntimeError('Install first: '+item['id'])
            command=[str(game/'LeoRacer.console.exe'),'--headless','--quit-after','3600','--','--drive-test','--workshop-test='+str(folder),'--workshop-test-probe']
            env=environment('exported-'+item['id']);env.pop('DOTNET_ROOT',None)
            env['PATH']=os.pathsep.join(p for p in env.get('PATH','').split(os.pathsep) if 'dotnet' not in p.lower())
            result=subprocess.run(command,cwd=game,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,errors='replace',timeout=180)
            log=WORK/item['id']/'exported-drive.log';log.write_text(result.stdout,encoding='utf-8')
            match=re.search(r'WORKSHOP_PRIVATE_TEST (\{[^\r\n]+\})',result.stdout)
            check=json.loads(match[1]) if match else {'status':'FAIL','error':'Missing exported test result'}
            check['ok']=result.returncode==0 and check['status']=='PASS' and 'SCRIPT ERROR' not in result.stdout
            progress=WORK/item['id']/'progress.json';state=read(progress);state['drive']=check;write(progress,state)
            results.append(check);print('DRIVE '+item['filename']+' '+str(check['ok']),flush=True)
        if not all(r['ok'] for r in results):raise RuntimeError('Private driving check failed')
    elif args.phase=='package':
        report=build_report(items,args.destination)
        if not report['core_unchanged'] or not report['stock_unchanged'] or not report['sources_unchanged']:raise RuntimeError('Protected file hash changed')
        if report['installed']!=len(items):raise RuntimeError('Install all validated cars before packaging')
        archive=ROOT/'dist/LeoRacer-local-car-collection.zip';archive.parent.mkdir(parents=True,exist_ok=True)
        folders=[args.destination/i['id'] for i in items]
        if (WORK/'reused.json').is_file():folders.append(Path(read(WORK/'reused.json')['folder']))
        with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as pack:
            for folder in folders:
                for p in sorted(folder.rglob('*')):
                    if p.is_file():pack.write(p,'GameAssets/vehicles/'+folder.name+'/'+p.relative_to(folder).as_posix())
            pack.write(WORK/'batch-report.json','batch-report.json')
            for name in ['profiles.json','facing.json']:
                if (WORK/name).is_file():pack.write(WORK/name,name)
            for p in sorted((WORK/'previews').glob('sheet-*.jpg')):pack.write(p,'previews/'+p.name)
            pack.writestr('README.txt',f'LOCAL CAR COLLECTION\nCopy GameAssets next to LeoRacer.exe. Existing stock folders are not included.\n{len(folders)} cars; no visible drivers; modded/unranked.\nSources retained locally; redistribution rights were not supplied.\nSee batch-report.json for per-car validation, sizes, hashes and authoring stages.\n')
        write(WORK/'package.json',{'archive':str(archive),'sha256':sha(archive),'bytes':archive.stat().st_size,'cars':len(folders),'installed_bytes':sum(p.stat().st_size for f in folders for p in f.rglob('*') if p.is_file())})
        print(json.dumps(read(WORK/'package.json'),indent=2))
    else:build_report(items,args.destination)

def build_report(items,destination):
    rows=[]
    for item in items:
        progress=WORK/item['id']/'progress.json';state=read(progress) if progress.is_file() else item
        folder=Path(state.get('output',''))
        installed=destination/item['id']
        files=list(folder.rglob('*')) if folder.is_dir() and state.get('output') else []
        matches=bool(files) and all((installed/p.relative_to(folder)).is_file() and sha(installed/p.relative_to(folder))==sha(p) for p in files if p.is_file())
        rows.append({k:v for k,v in state.items() if k!='converted'}|{'installed_matches_staged':matches,'conversion_ok':state.get('converted',{}).get('ok',False),'conversion_error':state.get('converted',{}).get('error',''),'model_bytes':(folder/'model.glb').stat().st_size if (folder/'model.glb').is_file() else 0,'folder_bytes':sum(p.stat().st_size for p in files if p.is_file())})
    baseline=read(WORK/'game-baseline.json');game=destination.resolve().parents[1]
    report={'format':1,'offline':True,'driver_tests':0,'cars':rows,'installed':sum(r['installed_matches_staged'] for r in rows),'source_files':len(rows),'sources_unchanged':all(sha(i['source'])==i['source_hash'] for i in items),'core_unchanged':all(sha(game/n)==h for n,h in baseline['core'].items()),'stock_unchanged':all((destination/n).is_file() and sha(destination/n)==h for n,h in baseline['stock'].items()),'source_bytes':sum(r['source_bytes'] for r in rows),'model_bytes':sum(r['model_bytes'] for r in rows),'folder_bytes':sum(r['folder_bytes'] for r in rows),'exceptions':[r['filename'] for r in rows if not r.get('validation',{}).get('ok')],'reused':read(WORK/'reused.json') if (WORK/'reused.json').is_file() else None}
    write(WORK/'batch-report.json',report);print(json.dumps({k:v for k,v in report.items() if k!='cars'},indent=2))
    return report

if __name__=='__main__':main()
