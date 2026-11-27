"""Publish the tested 2.4.1 core with official cars only; private imports stay local."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, zipfile
from release_231 import payload, files

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'build/Release-2.4.1-public'
OUT=ROOT/'dist/release-2.4.1'
QA=ROOT/'build/release241'
SOURCE=ROOT/'build/Distinct-v3-final'
OFFICIAL=set(json.loads((ROOT/'assets/config/official-vehicles.json').read_text(encoding='utf-8')))
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def dump(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
def prepare():
    assert not BASE.exists(), 'Public staging already exists; inspect before rebuilding'
    assert json.loads((ROOT/'build/distinct/final-acceptance.json').read_text())['status']=='PASS'
    BASE.mkdir(parents=True);OUT.mkdir(parents=True,exist_ok=True);QA.mkdir(parents=True,exist_ok=True)
    for name in ['LeoRacer.exe','LeoRacer.console.exe','LeoRacer.pck','data_LeoRacer_windows_x86_64','Tools','Vehicle Workshop.cmd']:
        src=SOURCE/name
        if src.is_dir():shutil.copytree(src,BASE/name)
        else:shutil.copy2(src,BASE/name)
    for src in (SOURCE/'GameAssets').iterdir():
        dst=BASE/'GameAssets'/src.name
        if src.name=='vehicles':
            for key in sorted(OFFICIAL):shutil.copytree(src/key,dst/key)
        elif src.is_dir():shutil.copytree(src,dst)
        else:dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
    assert {p.parent.name for p in (BASE/'GameAssets/vehicles').glob('*/vehicle.json')}==OFFICIAL
    assert sha(BASE/'LeoRacer.pck')==sha(SOURCE/'LeoRacer.pck')
    shutil.copy2(ROOT/'installer/InstallerContent.ps1',BASE/'InstallerContent.ps1')
    shutil.copy2(ROOT/'docs/DISTINCT_V3.md',BASE/'TEST_REPORT.md')
    (BASE/'README.txt').write_text('LEO RACER 2.4.1\n\nRun LeoRacer.exe. Includes all three tracks and 16 official cars.\nNo Godot, .NET SDK, account or network required.\nUse Play Compatibility.cmd if Vulkan is unavailable.\nPrivate imported models are not distributed. Existing user-added vehicles remain supported and unranked.\nSettings and legacy records are preserved; new records use distinct_v3.\nSee TEST_REPORT.md and GameAssets/licenses for validation and attribution.\n',encoding='utf-8')
    (BASE/'Play Compatibility.cmd').write_text('@echo off\ncd /d "%~dp0"\nstart "" "LeoRacer.exe" --rendering-method gl_compatibility --rendering-driver opengl3\n',encoding='ascii')
    dump(BASE/'release-build.json',{'version':'2.4.1','branch':'release/2.4.1','default_vehicles':16,'tracks':3,'private_imports_included':False,'tested_core_sha256':sha(BASE/'LeoRacer.pck')})
    # Retain the tested ownership/backup installer, without optional private cars.
    script=(ROOT/'installer/SelectableCars232.nsi').read_text(encoding='utf-8').replace('2.3.2','2.4.1').replace('release232-','release241-').replace('all tracks and 48 cars','all tracks and 16 official cars')
    script=script.replace('SectionGroup "Additional Cars (optional; select individually)" ADDONS\n !include "release241-cars.nsh"\nSectionGroupEnd\n','')
    script=script.replace('Choose tracks and additional cars below.','Choose tracks below.').replace('complete/custom offline installer','offline installer')
    (ROOT/'installer/OfficialCars241.nsi').write_text(script,encoding='utf-8')
    for suffix in ['required','tracks','descriptions','selection']:
        if suffix=='required':text=payload([p for p in files(BASE) if not p.relative_to(BASE).as_posix().startswith('GameAssets/tracks/')],BASE)
        else:
            spec=json.loads((ROOT/'content/releases/2.3.2.json').read_text(encoding='utf-8'))
            if suffix=='tracks':
                text='\n'.join('Section "'+row['name']+'" TRACK_'+str(i)+'\nSectionIn 1 2\n'+payload(files(BASE/'GameAssets/tracks'/row['id']),BASE)+'SectionEnd' for i,row in enumerate(spec['tracks']))
            elif suffix=='descriptions':
                text='\n'.join('!insertmacro MUI_DESCRIPTION_TEXT ${TRACK_'+str(i)+'} "'+row['name']+'; single-player and split-screen."' for i,row in enumerate(spec['tracks']))
            else:
                lines=['StrCpy $R3 ",$TrackSelection,"']
                for i,row in enumerate(spec['tracks']):
                    lines+=['SectionSetFlags ${TRACK_'+str(i)+'} 0','${StrStr} $R2 $R3 ",'+row['id']+',"','${If} $TrackSelection == "all"','${OrIf} $R2 != ""','SectionSetFlags ${TRACK_'+str(i)+'} ${SF_SELECTED}','${EndIf}']
                text='\n'.join(lines)
        (ROOT/('installer/release241-'+suffix+'.nsh')).write_text(text,encoding='utf-8')
    env=os.environ.copy();tmp=QA/'temp';tmp.mkdir(exist_ok=True);env['TEMP']=env['TMP']=str(tmp)
    with (QA/'installer-build.log').open('w',encoding='utf-8') as log:
        subprocess.run([str(ROOT/'.tools/nsis/nsis-3.13/Bin/makensis.exe'),'/V3','installer/OfficialCars241.nsi'],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=900)
    print('PUBLIC_BUILD_READY',sha(BASE/'LeoRacer.pck'),flush=True)
def package():
    report=json.loads((QA/'smoke.json').read_text());assert report['status']=='PASS'
    assert json.loads((QA/'installer.json').read_text())['status']=='PASS'
    shutil.copy2(QA/'installer.json',OUT/'INSTALLER_SMOKE.json')
    with zipfile.ZipFile(OUT/'LeoRacer-2.4.1-win64.zip','w',zipfile.ZIP_DEFLATED,compresslevel=4) as z:
        for p in files(BASE):z.write(p,'LeoRacer/'+p.relative_to(BASE).as_posix())
    with zipfile.ZipFile(OUT/'LeoRacer-2.4.1-win64.zip') as z:assert z.testzip() is None
    shutil.copy2(ROOT/'docs/RELEASE_NOTES_241.md',OUT/'RELEASE_NOTES-2.4.1.md')
    shutil.copy2(ROOT/'docs/DISTINCT_V3.md',OUT/'TEST_REPORT.md')
    shutil.copy2(QA/'smoke.json',OUT/'PUBLIC_SMOKE.json')
    with zipfile.ZipFile(OUT/'LeoRacer-2.4.1-Evidence.zip','w',zipfile.ZIP_DEFLATED) as z:
        for name in ['final-acceptance.json','performance-acceptance.json','packaged-acceptance.json','v3-regression/acceptance.json','pace-forward/pace.json','races-forward/races.json','features-forward/features.json','v3-framing/framing.json','v3-presentation-forward/presentation.json','v3-presentation-compatibility/presentation.json']:
            z.write(ROOT/'build/distinct'/name,name)
        for p in QA.glob('*.json'):z.write(p,'public/'+p.name)
    rows=[{'name':p.name,'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(OUT.iterdir()) if p.name not in ['SHA256SUMS.txt','release-manifest.json']]
    (OUT/'SHA256SUMS.txt').write_text(''.join(r['sha256']+'  '+r['name']+'\n' for r in rows),encoding='utf-8')
    rows.append({'name':'SHA256SUMS.txt','bytes':(OUT/'SHA256SUMS.txt').stat().st_size,'sha256':sha(OUT/'SHA256SUMS.txt')})
    dump(OUT/'release-manifest.json',{'version':'2.4.1','commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'official_cars':16,'private_models':0,'files':rows})
    print('PUBLIC_PACKAGE_READY',flush=True)
def publish():
    subprocess.run([os.sys.executable,str(ROOT/'tools/publish_content_release.py'),'--manifest',str(OUT/'release-manifest.json'),'--notes',str(ROOT/'docs/RELEASE_NOTES_241.md'),'--title','Leo Racer 2.4.1 - distinct cars, reliable races','--publish'],cwd=ROOT,check=True)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','package','publish']);a=p.parse_args();globals()[a.action]()
