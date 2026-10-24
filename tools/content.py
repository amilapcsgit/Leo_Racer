"""Independent data-content builds. Never exports an executable for vehicle/track targets."""
from pathlib import Path
import argparse, hashlib, json, shutil, struct, zipfile, subprocess, re

ROOT = Path(__file__).resolve().parents[1]
DEV = ('bigster', 'duster')

def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))

def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def model_document(path):
    with Path(path).open('rb') as stream:
        head = stream.read(20)
        assert len(head) == 20 and head[:4] == b'glTF', 'Not a binary glTF model'
        magic, version, total, length, kind = struct.unpack('<5I', head)
        assert version == 2 and kind == 0x4e4f534a and total == Path(path).stat().st_size
        assert length <= total-20
        data = json.loads(stream.read(length))
    for image in data.get('images', []):
        assert not image.get('uri') or image['uri'].startswith('data:'), 'Embed model textures before distribution'
    assert all(not b.get('uri') for b in data.get('buffers', [])), 'GLB must contain its geometry'
    return data

def relative_file(folder, name):
    assert isinstance(name,str) and name and not Path(name).is_absolute() and ':' not in name and '..' not in name.replace('\\','/').split('/')
    path=Path(folder)/name
    assert path.resolve().is_relative_to(Path(folder).resolve()),'Content reference escapes its folder'
    return path

def vehicle(key, destination, source_folder=None):
    assert re.fullmatch(r'[a-z0-9][a-z0-9_.-]{0,63}',key)
    if source_folder:
        source_folder=Path(source_folder).resolve();data=read(source_folder/'vehicle.json')
        assert data.get('id')==key and data.get('format')==1 and data.get('vehicle_api')==1
        model_document(relative_file(source_folder,data.get('model','model.glb')))
        folder=Path(destination)/key;folder.mkdir(parents=True,exist_ok=True)
        names=['vehicle.json',data.get('model','model.glb')]
        names += [n for n in [data.get('thumbnail','thumbnail.png'),'LICENSE.txt','optimized-textures.json'] if (source_folder/n).is_file()]
        if 'optimized-textures.json' in names:
            names += [entry['file'] for entry in read(source_folder/'optimized-textures.json').get('textures',[])]
        for name in names:
            original=relative_file(source_folder,name);target=relative_file(folder,name);target.parent.mkdir(parents=True,exist_ok=True)
            if original.resolve()!=target.resolve():shutil.copy2(original,target)
        return folder
    sources = read(ROOT/'content/vehicle-sources.json')
    assert key in sources, 'Unknown source vehicle: '+key
    source = sources[key]
    folder = Path(destination)/key
    folder.mkdir(parents=True, exist_ok=True)
    model = ROOT/source['model'].removeprefix('res://')
    model_document(model)
    shutil.copy2(model, folder/'model.glb')
    shutil.copy2(ROOT/'content/vehicles'/key/'vehicle.json', folder/'vehicle.json')
    if source.get('thumbnail'):
        shutil.copy2(ROOT/source['thumbnail'].removeprefix('res://'), folder/'thumbnail.png')
    (folder/'LICENSE.txt').write_text('Original Leo Racer vehicle, retained from v2.1.0.\n'
        'Original third-party notices and provenance are retained in GameAssets/licenses/.\n'
        'This file does not replace or expand those licenses.\n', encoding='utf-8')
    return folder

def registry():
    result = {}
    for key, source in read(ROOT/'content/vehicle-sources.json').items():
        text=(ROOT/'content/vehicles'/key/'vehicle.json').read_text(encoding='utf-8')
        result[key] = {'definition': hashlib.sha256(text.encode()).hexdigest(),
                       'model': sha(ROOT/source['model'].removeprefix('res://'))}
    (ROOT/'assets/config/official-vehicles.json').write_text(json.dumps(result, indent=2)+'\n')
    return result

def archive(folder, kind, content_id, destination):
    assert re.fullmatch(r'[a-z0-9][a-z0-9_.-]{0,63}',content_id)
    destination = Path(destination);destination.mkdir(parents=True, exist_ok=True)
    result = destination/f'LeoRacer-{kind}-{content_id}.zip'
    with zipfile.ZipFile(result, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for p in sorted(Path(folder).rglob('*')):
            if p.is_file():z.write(p, 'GameAssets/'+kind+'/'+content_id+'/'+p.relative_to(folder).as_posix())
    result.with_suffix('.sha256').write_text(sha(result)+'  '+result.name+'\n')
    return result

def file_map(folder):
    return {p.relative_to(folder).as_posix():p for p in Path(folder).rglob('*')
            if p.is_file() and p.suffix.lower() not in ['.log','.pdb']
            and not p.name.startswith('libterrain.windows.')}

def zip_files(files, destination, prefix='LeoRacer/'):
    destination.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(destination,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for name,p in sorted(files.items()):z.write(p,prefix+name)
    destination.with_suffix(destination.suffix+'.sha256').write_text(sha(destination)+'  '+destination.name+'\n')
    return destination

def core(folder, version):
    files={name:p for name,p in file_map(folder).items() if not name.startswith('GameAssets/') and name!='asset-sizes.json'}
    assert 'LeoRacer.exe' in files and 'LeoRacer.pck' in files
    result=zip_files(files,ROOT/'dist'/f'LeoRacer-Core-{version}-win64.zip')
    print('CORE_BUILT',result.name,'bytes=',result.stat().st_size)

def distribution(core_folder, profile, output, version):
    core_folder=core_folder.resolve();output=output.resolve()
    # Build outputs stay inside this repository; never remove arbitrary folders.
    assert output.is_relative_to(ROOT/'build') and output!=ROOT/'build'
    assert (core_folder/'GameAssets/catalog.json').exists(),'Build the core cache once first'
    desired=file_map(core_folder)
    desired.pop('asset-sizes.json',None)
    keys=DEV if profile=='dev' else read(ROOT/'content/vehicle-sources.json').keys()
    for key in keys:
        folder=vehicle(key,ROOT/'build/content-vehicles')
        for name,p in file_map(folder).items():desired['GameAssets/vehicles/'+key+'/'+name]=p
    previous=read(output/'.managed-build.json') if (output/'.managed-build.json').exists() else {}
    for name,digest in previous.items():
        path=output/name
        assert path.resolve().is_relative_to(output)
        if name not in desired and path.is_file() and sha(path)==digest:path.unlink()
    for name,source in desired.items():
        target=output/name;target.parent.mkdir(parents=True,exist_ok=True)
        if target.exists() and name in previous and sha(target)!=previous[name]:
            backup=target.with_name(target.name+'.user-backup')
            if not backup.exists():shutil.copy2(target,backup)
        shutil.copy2(source,target)
    development='-' in version
    readme=output/'README.txt'
    readme.write_text('LEO RACER '+version+' / '+profile.upper()+' PROFILE\n'
      'Run LeoRacer.exe; keep the complete folder together. No SDK or network is required.\n'
      'Content > Vehicles discovers folders and standalone GLBs in GameAssets/vehicles.\n'
      'Import GLB opens the offline Vehicle Workshop in a separate window. Confirm orientation and four wheels, preview/test, then Install.\n'
      'Vehicle Workshop.cmd also launches the companion directly. No extra engine/editor installation is needed.\n'
      'Mesh/texture caches are disposable files in Godot user data; authoritative GLBs stay loose.\n'
      'Install compatible track folders in GameAssets/tracks while the game is closed.\n'
      'Existing controls/settings/rankings are preserved. Custom content cannot set official records.\n'
      +('Development build. ' if development else 'Release build. ')+'Vehicles: '+', '.join(keys)+'.\n'
      'Attribution: GameAssets/licenses and individual content LICENSE.txt files.\n',encoding='utf-8')
    (output/'Play Compatibility.cmd').write_text('@echo off\ncd /d "%~dp0"\nstart "" "LeoRacer.exe" --rendering-method gl_compatibility --rendering-driver opengl3\n',encoding='ascii')
    metadata={'version':version,'branch':subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip(),'profile':profile,'vehicles':list(keys),
              'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
              'public_release':not development,'template':'Godot 4.7.2 checked/debug'}
    (output/'development-build.json').write_text(json.dumps(metadata,indent=2)+'\n')
    for name in ['README.txt','Play Compatibility.cmd','development-build.json']:desired[name]=output/name
    files={name:output/name for name in desired}
    owned={name:sha(p) for name,p in files.items()}
    (output/'.managed-build.json').write_text(json.dumps(owned,indent=2)+'\n')
    suffix=('' if profile=='dev' else '-full') if development else ('-dev' if profile=='dev' else '')
    result=zip_files(files,ROOT/'dist'/f'LeoRacer-{version}{suffix}-win64.zip')
    report={'status':'PASS','profile':profile,'vehicles':list(keys),'exe_bytes':(output/'LeoRacer.exe').stat().st_size,
            'core_bytes':(output/'LeoRacer.pck').stat().st_size,'installed_bytes':sum(p.stat().st_size for p in files.values()),
            'compressed_bytes':result.stat().st_size,'archive':result.name,'sha256':sha(result),
            'vehicle_bytes':sum(p.stat().st_size for n,p in files.items() if n.startswith('GameAssets/vehicles/')),
            'track_bytes':{p.name:sum(f.stat().st_size for f in p.rglob('*') if f.is_file()) for p in (output/'GameAssets/tracks').iterdir() if p.is_dir()},
            'core_export_invoked':False}
    (ROOT/'build/modularity').mkdir(parents=True,exist_ok=True)
    (ROOT/'build/modularity'/f'package-{profile}.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))

def sdk():
    files={p.relative_to(ROOT/'sdk').as_posix():p for p in (ROOT/'sdk').rglob('*')
           if p.is_file() and not any(part in ['.godot','exported','.gdignore'] for part in p.relative_to(ROOT/'sdk').parts)}
    for p in (ROOT/'content/schemas').glob('*.json'):files['schemas/'+p.name]=p
    files['vehicle-tools/optimize_vehicle.gd']=ROOT/'tools/optimize_vehicle.gd'
    files['LICENSE']=ROOT/'LICENSE'
    result=zip_files(files,ROOT/'dist/LeoRacer-Contributor-SDK.zip',prefix='LeoRacer-SDK/')
    print('CONTRIBUTOR_SDK_BUILT',result.name)

def main():
    parser=argparse.ArgumentParser()
    sub=parser.add_subparsers(dest='target',required=True)
    p=sub.add_parser('registry')
    p=sub.add_parser('stage');p.add_argument('--profile',choices=['dev','full'],default='dev');p.add_argument('--output',type=Path,default=ROOT/'build/Modularity/GameAssets')
    p=sub.add_parser('vehicle');p.add_argument('id');p.add_argument('--output',type=Path,default=ROOT/'build/content-vehicles');p.add_argument('--source-folder',type=Path);p.add_argument('--zip',action='store_true')
    p=sub.add_parser('core');p.add_argument('--folder',type=Path,required=True);p.add_argument('--version',default='2.2.0-modularity-dev')
    p=sub.add_parser('track');p.add_argument('id');p.add_argument('--source-folder',type=Path)
    p=sub.add_parser('distribution');p.add_argument('--core',type=Path,default=ROOT/'build/ModularityCore');p.add_argument('--profile',choices=['dev','full'],default='dev');p.add_argument('--output',type=Path,required=True);p.add_argument('--version',default='2.2.0-modularity-dev')
    p=sub.add_parser('sdk')
    p=sub.add_parser('workshop');p.add_argument('--folder',type=Path,default=ROOT/'build/VehicleWorkshop')
    args=parser.parse_args()
    if args.target=='registry':print('OFFICIAL_VEHICLES',len(registry()));return
    if args.target=='stage':
        keys=DEV if args.profile=='dev' else read(ROOT/'content/vehicle-sources.json').keys()
        for key in keys:vehicle(key,args.output/'vehicles')
        print(json.dumps({'status':'PASS','profile':args.profile,'vehicles':list(keys),'core_export_invoked':False}))
    elif args.target=='vehicle':
        folder=vehicle(args.id,args.output,args.source_folder)
        result=archive(folder,'vehicles',args.id,ROOT/'dist/content') if args.zip else folder
        print('VEHICLE_BUILT',args.id,result.name,'core_export_invoked=false')
    elif args.target=='core':core(args.folder,args.version)
    elif args.target=='distribution':distribution(args.core,args.profile,args.output,args.version)
    elif args.target=='track':
        assert re.fullmatch(r'[a-z0-9][a-z0-9_.-]{0,63}',args.id)
        folder=args.source_folder or ROOT/'build/content-tracks'/args.id;assert (folder/'manifest.json').exists(),'Export the track first'
        result=archive(folder,'tracks',args.id,ROOT/'dist/content');print('TRACK_BUILT',result.name,'core_export_invoked=false')
    elif args.target=='sdk':sdk()
    elif args.target=='workshop':
        files={'Tools/VehicleWorkshop/'+name:args.folder/name for name in ['workshop.pck','workshop.json']}
        assert all(p.is_file() for p in files.values()),'Build the Workshop PCK first'
        metadata=read(args.folder/'workshop.json')
        assert metadata['sha256']==sha(args.folder/'workshop.pck')
        result=zip_files(files,ROOT/'dist/LeoRacer-VehicleWorkshop-dev.zip')
        print('WORKSHOP_BUILT',result.name,'bytes=',result.stat().st_size,'core_export_invoked=false')

if __name__=='__main__':main()
