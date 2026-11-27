"""Assemble a local complete candidate; preserve private vehicle/track packages."""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess, zipfile, os
import city_packs

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT.parent.parent/'t232/r232-complete'
CANDIDATE=Path(os.environ.get('LEO_CANDIDATE_DIR',str(ROOT/'build/Distinct-v3-final')))
OUT=ROOT/'dist/distinct-v3'
QA=ROOT/'build/distinct'

def digest(path):
    with path.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()

def stage():
    assert (CANDIDATE/'LeoRacer.exe').is_file()
    _,full_entries=city_packs.read_pack(CANDIDATE/'LeoRacer.pck')
    if not any(name.startswith('assets/models/colombo_city/') for name in full_entries):
        raise ValueError('Export the complete PCK with build_distinct.ps1 before staging; this core is already split.')
    shutil.copytree(BASE/'GameAssets',CANDIDATE/'GameAssets',dirs_exist_ok=True)
    city_packs.split(CANDIDATE,loose_vehicles=True)
    # Track scenery is an independently versioned package. Keep the tested
    # baseline packages and trust those actual pack hashes, including Kandy.
    shutil.copytree(BASE/'GameAssets/tracks',CANDIDATE/'GameAssets/tracks',dirs_exist_ok=True)
    engine,entries=city_packs.read_pack(CANDIDATE/'LeoRacer.pck')
    trusted={}
    for folder in (CANDIDATE/'GameAssets/tracks').iterdir():
        if not (folder/'manifest.json').is_file():continue
        metadata=json.loads((folder/'manifest.json').read_text())
        trusted[metadata['id']+':'+str(int(metadata.get('course_revision',1)))]=[digest(folder/pack['file']) for pack in metadata.get('packs',[])]
    entries['assets/config/official-track-content.json']=json.dumps(trusted,sort_keys=True).encode()
    # These resources are preloaded by global scripts before external packs mount.
    for name in ['automotive_paint','automotive_glass']:
        path='assets/materials/'+name+'.tres'
        entries[path]=(ROOT/path).read_bytes()
    city_packs.write_pack(CANDIDATE/'LeoRacer.pck',engine,entries)
    assert 'assets/config/vehicle-balance-v2.json' in entries
    # Every installed car, especially Bigster, is copied byte-for-byte.
    preserved=[]
    for source in sorted((BASE/'GameAssets/vehicles').rglob('*')):
        if not source.is_file():continue
        target=CANDIDATE/'GameAssets/vehicles'/source.relative_to(BASE/'GameAssets/vehicles')
        assert digest(source)==digest(target),source
        preserved.append(source.relative_to(BASE).as_posix())
    report=dict(version='2.4.1',ruleset='distinct_v3',public_release=False,private_imports=True,vehicles=48,tracks=3,preserved_vehicle_files=len(preserved),source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip())
    (CANDIDATE/'candidate-build.json').write_text(json.dumps(report,indent=2)+'\n')
    (QA/'package-preservation.json').write_text(json.dumps(report,indent=2)+'\n')
    (CANDIDATE/'Play Test Build.cmd').write_text('@echo off\r\ncd /d "%~dp0"\r\nset "APPDATA=%~dp0TestProfile"\r\nset "LOCALAPPDATA=%~dp0TestProfile"\r\nstart "" "%~dp0LeoRacer.exe"\r\n',encoding='ascii')
    (CANDIDATE/'Play Compatibility.cmd').write_text('@echo off\r\ncd /d "%~dp0"\r\nset "APPDATA=%~dp0TestProfile"\r\nset "LOCALAPPDATA=%~dp0TestProfile"\r\nstart "" "%~dp0LeoRacer.exe" --rendering-method gl_compatibility --rendering-driver opengl3\r\n',encoding='ascii')
    (CANDIDATE/'README.txt').write_text('LEO RACER 2.4.1 / DISTINCT VEHICLES TEST CANDIDATE\n\nExtract the complete folder and run Play Test Build.cmd.\nThe launcher uses a private TestProfile folder beside the game.\nPlay Compatibility.cmd selects OpenGL for older hardware.\n\n48 balanced vehicles; fair racing AI; spring camera; graphics presets; layered audio.\nBigster is restored to 100% size; original assets and manual driving coefficients are preserved. Detailed single-player HUD and lap/controller fixes included. New race records use distinct_v3.\nSettings includes graphics quality, camera field of view, and Reduced Motion.\nSplit-screen caps graphics at Medium. All prior vehicle controls remain available.\n\nThis local package includes your personal imports. Keep it private; redistribution rights are not supplied.\nSee TEST_REPORT.md for measurements and remaining limitations.\n',encoding='utf-8')
    print(json.dumps(report),flush=True)

def package():
    OUT.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/'docs/DISTINCT_V3.md',CANDIDATE/'TEST_REPORT.md')
    archive=OUT/'LeoRacer-2.4.1-distinct-v3-private-win64.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=4) as bundle:
        for path in sorted(CANDIDATE.rglob('*')):
            if path.is_file() and 'TestProfile' not in path.parts and path.suffix!='.pdb':bundle.write(path,(Path('LeoRacer')/path.relative_to(CANDIDATE)).as_posix())
    with zipfile.ZipFile(archive) as bundle:assert bundle.testzip() is None
    evidence=OUT/'LeoRacer-distinct-v3-evidence.zip'
    with zipfile.ZipFile(evidence,'w',zipfile.ZIP_DEFLATED,compresslevel=4) as bundle:
        for path in sorted(QA.rglob('*')):
            if path.is_file() and not any(part in ['profiles','export-profile','temp','TestProfile'] for part in path.relative_to(QA).parts) and path.suffix in ['.json','.log','.png','.gd','.wav']:
                bundle.write(path,path.relative_to(QA).as_posix())
    files=[dict(name=path.name,bytes=path.stat().st_size,sha256=digest(path)) for path in [archive,evidence]]
    (OUT/'SHA256SUMS.txt').write_text(''.join(row['sha256']+'  '+row['name']+'\n' for row in files))
    (OUT/'manifest.json').write_text(json.dumps(dict(version='2.4.1',public_release=False,files=files),indent=2)+'\n')
    print(json.dumps(files),flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('mode',choices=['stage','package']);args=parser.parse_args();globals()[args.mode]()
