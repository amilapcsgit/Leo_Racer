"""Build and independently exercise an extracted, SDK-free development package."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, time, uuid, zipfile
ROOT=Path(__file__).resolve().parents[1]
VERSION='1.8.0'

def run_game(folder,arguments,expected,environment,code=0):
    print('OFFLINE_CHECK',arguments,flush=True)
    result=subprocess.run([str(folder/'LeoRacer.console.exe'),'--headless','--quit-after','18000','--',*arguments],cwd=folder,env=environment,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=240,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    output=result.stdout+result.stderr
    log=folder.parent/('check-'+str(time.time_ns())+'.log');log.write_text(output,encoding='utf-8')
    assert result.returncode==code,(result.returncode,output[-5000:])
    assert expected in output and 'SCRIPT ERROR' not in output,output[-5000:]
    print('OFFLINE_CHECK PASS',arguments,flush=True)
    return output

def verify(folder,report_path=None):
    environment=os.environ.copy()
    for key in list(environment):
        if key.upper().startswith(('DOTNET','MSBUILD')):environment.pop(key)
    environment['PATH']=';'.join(p for p in environment.get('PATH','').split(';') if 'dotnet' not in p.lower())
    environment['APPDATA']=str(folder.parent/'isolated-user-data')
    environment['DOTNET_BUNDLE_EXTRACT_BASE_DIR']=str(folder.parent/'isolated-launcher-runtime')
    Path(environment['APPDATA']).mkdir(exist_ok=True)
    checks=[]
    assert list(folder.rglob('e_sqlite3.dll')) and list(folder.rglob('coreclr.dll')),'Self-contained .NET / SQLite missing'
    checks.append('Self-contained game, .NET and Windows SQLite; no duplicate launcher runtime')
    output=run_game(folder,['--verify-content'],'CONTENT_VALIDATION_OK',environment)
    assert 'astra_coast' in output and 'colombo_city' in output
    checks.append('Offline catalog, shared packs and both track packs verified')
    for track in ['astra_coast','colombo_city']:
        run_game(folder,['--smoke-test','--drive-test','--track='+track],'LEO_TEST_REPORT',environment)
        report=json.loads((folder/'smoke-test.json').read_text(encoding='utf-8'));assert report['status']=='PASS',report
        checks.append(track+': race, garage, split views and SQLite transactions')
    catalog_path=folder/'GameAssets/catalog.json';original=catalog_path.read_bytes()
    catalog=json.loads(original);pack=folder/'GameAssets'/catalog['packs'][0]['file'];backup=pack.with_suffix('.test-backup')
    assert not backup.exists();pack.rename(backup)
    try:run_game(folder,['--verify-content'],'Missing asset pack:',environment,2)
    finally:backup.rename(pack)
    checks.append('Missing required pack produces readable failure')
    try:
        catalog['packs'][0]['sha256']='0'*64;catalog_path.write_text(json.dumps(catalog),encoding='utf-8')
        run_game(folder,['--verify-content'],'Damaged asset pack:',environment,2)
    finally:catalog_path.write_bytes(original)
    checks.append('Corrupt pack produces readable failure')
    track_pack=folder/'GameAssets/tracks/colombo_city/scenery.pck';backup=track_pack.with_suffix('.test-backup')
    assert not backup.exists();track_pack.rename(backup)
    try:run_game(folder,['--verify-content'],'Missing track scenery:',environment,2)
    finally:backup.rename(track_pack)
    checks.append('Missing per-track scenery produces readable failure')
    # A new manifest/route/scenery folder is discovered by the unchanged executable.
    source=folder/'GameAssets/tracks/colombo_city';addon=source.parent/'offline_addon_test'
    assert not addon.exists();addon.mkdir()
    for name in ['route.json','cells.json','scenery.pck']:os.link(source/name,addon/name)
    metadata=json.loads((source/'manifest.json').read_text(encoding='utf-8'));metadata.update(id='offline_addon_test',name='Offline Compatible Track')
    (addon/'manifest.json').write_text(json.dumps(metadata),encoding='utf-8')
    try:
        output=run_game(folder,['--verify-content'],'CONTENT_VALIDATION_OK',environment);assert 'offline_addon_test' in output
        run_game(folder,['--smoke-test','--drive-test','--track=offline_addon_test'],'LEO_TEST_REPORT',environment)
        assert json.loads((folder/'smoke-test.json').read_text(encoding='utf-8'))['status']=='PASS'
    finally:
        for name in ['route.json','cells.json','scenery.pck','manifest.json']:(addon/name).unlink()
        addon.rmdir()
    checks.append('Additional compatible track discovered and raced without executable rebuild')
    result={'status':'PASS','checks':checks,'sdk_environment_removed':True,'network_required':False,'folder':str(folder)}
    if report_path:report_path.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,indent=2));return result

def package(public_release=False):
    folder=ROOT/'build/ColomboCity'
    for name in ['smoke-test.json','race-test.json']:
        path=folder/name
        if path.exists():path.unlink()
    launcher=folder/'Leo Racer Launcher.exe'
    if launcher.exists():launcher.unlink()
    for symbols in folder.rglob('*.pdb'):symbols.unlink()
    for library in folder.glob('libterrain.windows.*.dll'):library.unlink()
    (folder/'Play Compatibility.cmd').write_text('@echo off\ncd /d "%~dp0"\nstart "" "LeoRacer.exe" --rendering-method gl_compatibility --rendering-driver opengl3\n',encoding='ascii')
    (folder/'README.txt').write_text('LEO RACER / COLOMBO CITY\n\nRun LeoRacer.exe (or Play Compatibility.cmd for OpenGL). Keep the complete folder together. No SDK or network is required.\nSelect Colombo City Grand Prix (5.5 km) or the preserved Astra Lotus Coast. Both support single player and two-player split screen.\nSettings and named rankings remain in the existing Godot user-data directory. The installer preserves settings and rankings.\nGameAssets/catalog.json registers category packs and optional cosmetic overrides. Complete compatible track folders can be added under GameAssets/tracks. See GameAssets/README.txt.\nAttribution and licenses: GameAssets/licenses. Colombo map context: OpenStreetMap contributors / ODbL / https://www.openstreetmap.org/copyright.\nVersion '+VERSION+' / colombo-city. The previously published v1.7.0 release is unchanged.\n',encoding='utf-8')
    commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    (folder/'development-build.json').write_text(json.dumps({'version':VERSION,'branch':'colombo-city','template':'Godot 4.7.2 checked / debug','source_commit':commit,'source_dirty':bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True).strip()),'public_release':public_release},indent=2)+'\n',encoding='utf-8')
    sizes_path=folder/'asset-sizes.json';sizes=json.loads(sizes_path.read_text(encoding='utf-8'))
    for _ in range(2):
        sizes['installed_bytes']=sum(p.stat().st_size for p in folder.rglob('*') if p.is_file())
        sizes_path.write_text(json.dumps(sizes,indent=2)+'\n',encoding='utf-8')
    dist=ROOT/'dist';dist.mkdir(exist_ok=True)
    archive=dist/('LeoRacer-'+VERSION+'-win64.zip')
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for path in sorted(folder.rglob('*')):
            z.write(path,'LeoRacer/'+path.relative_to(folder).as_posix())
    extraction=ROOT/'build/offline-city'/uuid.uuid4().hex;extraction.mkdir(parents=True)
    with zipfile.ZipFile(archive) as z:z.extractall(extraction)
    verify(extraction/'LeoRacer',ROOT/'docs/qa-colombo-city/offline-package.json')
    files=list(p for p in folder.rglob('*') if p.is_file());packs=list((folder/'GameAssets').rglob('*.pck'))
    report={'status':'PASS','exe_bytes':(folder/'LeoRacer.exe').stat().st_size,'core_bytes':(folder/'LeoRacer.pck').stat().st_size,
            'launcher_bytes':0,'shared_packs_bytes':sum(p.stat().st_size for p in packs if 'tracks' not in p.relative_to(folder/'GameAssets').parts),
            'track_bytes':{p.name:sum(f.stat().st_size for f in p.rglob('*') if f.is_file()) for p in (folder/'GameAssets/tracks').iterdir() if p.is_dir()},
            'installed_bytes':sum(p.stat().st_size for p in files),'compressed_bytes':archive.stat().st_size,'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'archive':str(archive),'extracted_folder':str(extraction/'LeoRacer')}
    (ROOT/'docs/qa-colombo-city/package.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(json.dumps(report,indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--verify-folder',type=Path);parser.add_argument('--version',default=VERSION);parser.add_argument('--public-release',action='store_true');args=parser.parse_args();VERSION=args.version
    if args.verify_folder:verify(args.verify_folder.resolve(),ROOT/'docs/qa-colombo-city/installer-content.json')
    else:package(args.public_release)
