"""Private 20-car 2.5 candidate assembly and repeatable RC acceptance."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, sys, zipfile
import city_packs, qa_distinct
ROOT=Path(__file__).resolve().parents[1]
RC=ROOT/'build/Distinct-v3-final'
QA=ROOT/'build/quality25'
SELECTED=QA/'selected-vehicles'
MANIFEST=ROOT/'assets/config/default-roster-v1.json'
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def dump(p,value):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
def verify_roster(folder):
    spec=json.loads(MANIFEST.read_text(encoding='utf-8'))
    expected={row['id'] for row in spec['vehicles']}
    assert {p.parent.name for p in folder.glob('*/vehicle.json')}==expected,'Unexpected default roster'
    count=0
    for row in spec['vehicles']:
        for name,digest in row['files'].items():assert sha(folder/row['id']/name)==digest,(row['id'],name);count+=1
    return count
def stage(folder):
    assert folder.resolve().is_relative_to((ROOT/'build').resolve()) and folder.resolve()!=RC.resolve()
    verify_roster(SELECTED);verify_roster(RC/'GameAssets/vehicles')
    _,entries=city_packs.read_pack(folder/'LeoRacer.pck')
    assert any(name.startswith('assets/models/colombo_city/') for name in entries),'Export a full PCK before staging'
    shutil.copytree(RC/'GameAssets',folder/'GameAssets',dirs_exist_ok=True)
    city_packs.split(folder,loose_vehicles=True)
    shutil.copytree(RC/'GameAssets/tracks',folder/'GameAssets/tracks',dirs_exist_ok=True)
    ids={p.name for p in SELECTED.iterdir() if (p/'vehicle.json').is_file()}
    for child in (folder/'GameAssets/vehicles').iterdir():
        if child.is_dir() and child.name not in ids:
            assert child.resolve().is_relative_to((folder/'GameAssets/vehicles').resolve())
            shutil.rmtree(child) # Only extra packages generated inside the new candidate.
    for key in ids:shutil.copytree(SELECTED/key,folder/'GameAssets/vehicles'/key,dirs_exist_ok=True)
    engine,entries=city_packs.read_pack(folder/'LeoRacer.pck')
    trusted={}
    for track in (folder/'GameAssets/tracks').iterdir():
        if not (track/'manifest.json').is_file():continue
        meta=json.loads((track/'manifest.json').read_text(encoding='utf-8'))
        trusted[meta['id']+':'+str(int(meta.get('course_revision',1)))]=[sha(track/pack['file']) for pack in meta.get('packs',[])]
    entries['assets/config/official-track-content.json']=json.dumps(trusted,sort_keys=True).encode()
    for name in ['automotive_paint','automotive_glass']:
        key='assets/materials/'+name+'.tres';entries[key]=(ROOT/key).read_bytes()
    city_packs.write_pack(folder/'LeoRacer.pck',engine,entries)
    preserved=verify_roster(folder/'GameAssets/vehicles')
    shutil.copy2(MANIFEST,folder/'default-roster-v1.json')
    for name,args in [('Play Test Build.cmd',''),('Play Compatibility.cmd','--rendering-method gl_compatibility --rendering-driver opengl3')]:
        (folder/name).write_text('@echo off\ncd /d "%~dp0"\nset "APPDATA=%~dp0TestProfile"\nset "LOCALAPPDATA=%~dp0TestProfile"\nstart "" "%~dp0LeoRacer.exe" '+args+'\n',encoding='ascii')
    (folder/'README.txt').write_text('LEO RACER 2.5 LOCAL CANDIDATE\n\nRun Play Test Build.cmd (Forward+) or Play Compatibility.cmd (OpenGL).\nUses an isolated TestProfile beside this build.\n20 selected cars, three tracks, RC AI/handling/HUD/audio, new contact response and cosmetic damage.\nNew records use distinct_v4. Sources and vehicle packages remain unchanged.\nThis includes personal models: keep this candidate private.\nManual add-ons: copy a complete Vehicle API 1 folder into GameAssets/vehicles, then refresh Content in game.\nAutomatic AI grids continue to use the locked twenty-car roster.\n',encoding='utf-8')
    report={'version':'2.5.0','public_release':False,'baseline':'Distinct-v3-final','default_roster':'focused20_v1','vehicles':20,'tracks':3,'unchanged_package_files':preserved,'core_sha256':sha(folder/'LeoRacer.pck'),'exe_sha256':sha(folder/'LeoRacer.exe'),'rc_core_sha256':sha(RC/'LeoRacer.pck')}
    dump(folder/'candidate-build.json',report);dump(QA/(folder.name+'-package.json'),report)
    print('QUALITY25_STAGED',json.dumps(report),flush=True)
def run_suite(name):
    suites={'audit':('tests/quality25_test.gd',()),'contacts':('tests/quality25_test.gd',('--quality25-mode=contacts',)),'regression':('tests/v3_acceptance.gd',()),'framing':('tests/v3_framing.gd',())}
    if name in suites:
        script,extra=suites[name];return qa_distinct.run('q25-'+name,script,extra=extra,vehicles=SELECTED)
    return qa_distinct.run('q25-'+name,mode=name,vehicles=SELECTED,timeout=2400)
def preserve_optional():
    full=ROOT.parent.parent/'t232/r232-complete/GameAssets/vehicles'
    selected={row['id'] for row in json.loads(MANIFEST.read_text(encoding='utf-8'))['vehicles']}
    excluded=[p for p in full.iterdir() if (p/'vehicle.json').is_file() and p.name not in selected]
    assert len(excluded)==28
    out=ROOT/'dist/quality25/ExcludedCars-28-local-only.zip';out.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED,compresslevel=4) as z:
        for folder in sorted(excluded):
            for p in sorted(folder.rglob('*')):
                if p.is_file():z.write(p,'GameAssets/vehicles/'+p.relative_to(full).as_posix())
    with zipfile.ZipFile(out) as z:assert z.testzip() is None
    dump(QA/'optional-packages.json',{'count':28,'ids':[p.name for p in excluded],'archive_sha256':sha(out),'public':False})
    print('OPTIONAL_CARS_PRESERVED',28,sha(out),flush=True)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['stage','optional','audit','contacts','regression','features','pace','races','framing']);p.add_argument('--folder',type=Path,default=ROOT/'build/Quality25-M1');a=p.parse_args()
    if a.action=='stage':stage(a.folder)
    elif a.action=='optional':preserve_optional()
    else:raise SystemExit(0 if run_suite(a.action) else 2)
