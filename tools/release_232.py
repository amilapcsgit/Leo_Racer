"""Promote the accepted candidate and build a complete/custom offline installer."""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess, os
from release_231 import payload, files, nsis, archive, sha, dump
from city_packs import read_pack, write_pack
from candidate_232 import archive as evidence_archive

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'build/Release-2.3.2-public'
CANDIDATE=ROOT/'build/Release-2.3.2'
ADDONS=ROOT/'build/a'
OUT=ROOT/'dist/release-2.3.2'
QA=ROOT/'build/release232'
SPEC=json.loads((ROOT/'content/releases/2.3.2.json').read_text(encoding='utf-8'))

def assemble():
    accepted=json.loads((ROOT/'docs/qa-vehicle232/extracted-package.json').read_text(encoding='utf-8'))
    assert accepted['status']=='PASS' and sha(CANDIDATE/'LeoRacer.exe')==accepted['exe_sha256']
    assert sha(CANDIDATE/'LeoRacer.pck')==accepted['core_sha256']
    assert json.loads((CANDIDATE/'GameAssets/vehicles/bigster/vehicle.json').read_text(encoding='utf-8'))['version']=='1.2.1'
    shutil.copytree(CANDIDATE,BASE,dirs_exist_ok=True)
    assert BASE.resolve().is_relative_to((ROOT/'build').resolve())
    (BASE/'candidate-build.json').unlink(missing_ok=True)
    shutil.copy2(ROOT/'installer/InstallerContent.ps1',BASE/'InstallerContent.ps1')
    # Kandy's validated route/content were absent from the older core registries.
    # Register those exact unchanged packages; do not rewrite the track itself.
    engine,entries=read_pack(BASE/'LeoRacer.pck');before=entries.copy()
    for name in ['official-tracks.json','official-track-content.json']:
        key='assets/config/'+name;registry=json.loads(entries[key])
        for row in SPEC['tracks']:
            folder=BASE/'GameAssets/tracks'/row['id'];meta=json.loads((folder/'manifest.json').read_text(encoding='utf-8-sig'))
            identifier=row['id']+':'+str(meta['course_revision'])
            registry[identifier]=sha(folder/meta.get('route','route.json')) if name=='official-tracks.json' else [sha(folder/p['file']) for p in meta.get('packs',[])]
        text=json.dumps(registry,indent=2)+'\n';(ROOT/key).write_text(text,encoding='utf-8');entries[key]=text.encode()
    write_pack(BASE/'LeoRacer.pck',engine,entries)
    dump(QA/'promotion.json',{'accepted_exe_sha256':accepted['exe_sha256'],'changed_core_resources':[k for k in entries if entries[k]!=before[k]],'other_core_resources_unchanged':True,'tracks_unchanged':True})
    (BASE/'README.txt').write_text('LEO RACER 2.3.2 — WINDOWS RELEASE\n\nRun LeoRacer.exe. Includes Astra Lotus Coast, Colombo City and Kandy Lake, plus 16 default cars.\nThe offline installer offers Complete (all 48 cars), Standard (16 cars), or Custom track/additional-car selection. At least one track is required.\nL headlights; O Bigster sunroof; K second action; C held Look Back; right-mouse drag or right stick orbit. All buttons can be remapped in Controls.\nReverse travel automatically turns the chase camera. Each local player has independent camera/lamp/action state.\nBigster 1.2.1: red Y-shaped rear LEDs, separate white bumper reversing lamp, main headlamp optics and signature strips.\nNo Godot/.NET installation, account, or network is needed to play. Use Play Compatibility.cmd if Vulkan is unavailable.\nExisting settings/records and user-added cars are preserved. Replaced modified files are backed up under ContentBackups. Deselecting previously installed content preserves it.\nPortable users may copy additional cars from the separate add-on ZIP. Imported cars are unranked and have no visible driver.\nSee VEHICLE_FEATURES.md, TEST_REPORT.md, GameAssets/licenses and each car LICENSE.txt.\n',encoding='utf-8')
    dump(BASE/'release-build.json',{'version':'2.3.2','branch':'orbitcamera','bigster_package':'1.2.1','default_vehicles':16,'tracks':3,'public_release':True})
    assert len(list((BASE/'GameAssets/vehicles').glob('*/vehicle.json')))==16
    assert len(list((ADDONS/'GameAssets/vehicles').glob('*/vehicle.json')))==32
    OUT.mkdir(parents=True,exist_ok=True);QA.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/'docs/RELEASE_NOTES_232.md',OUT/'RELEASE_NOTES-2.3.2.md')
    old=ROOT/'dist/release-2.3.1/ATTRIBUTION-2.3.1.txt'
    (OUT/'ATTRIBUTION-2.3.2.txt').write_text(old.read_text(encoding='utf-8').replace('LEO RACER 2.3.1 - CONTENT ATTRIBUTION','LEO RACER 2.3.2 - CONTENT ATTRIBUTION')+'\nBigster 1.2.1 optical derivative: source provenance unchanged; exact source hashes in feature-authoring.json.\n',encoding='utf-8')
    core=[p for p in files(BASE) if not p.relative_to(BASE).as_posix().startswith('GameAssets/tracks/')]
    (ROOT/'installer/release232-required.nsh').write_text(payload(core,BASE),encoding='utf-8')
    sections=[];descriptions=[];selection=['StrCpy $R3 ",$TrackSelection,"']
    for i,row in enumerate(SPEC['tracks']):
        folder=BASE/'GameAssets/tracks'/row['id'];size=sum(p.stat().st_size for p in files(folder))
        sections += ['Section "'+nsis(row['name'])+' ('+f'{size/1e6:.1f}'+' MB)" TRACK_'+str(i),'SectionIn 1 2',payload(files(folder),BASE),'SectionEnd']
        descriptions.append('!insertmacro MUI_DESCRIPTION_TEXT ${TRACK_'+str(i)+'} "'+nsis(row['name'])+'; single-player and split-screen."')
        selection += ['SectionSetFlags ${TRACK_'+str(i)+'} 0','${StrStr} $R2 $R3 ",'+row['id']+',"','${If} $TrackSelection == "all"','${OrIf} $R2 != ""','SectionSetFlags ${TRACK_'+str(i)+'} ${SF_SELECTED}','${EndIf}']
    (ROOT/'installer/release232-tracks.nsh').write_text('\n'.join(sections),encoding='utf-8')
    sections=[];selection+=['StrCpy $R3 ",$CarSelection,"']
    for i,row in enumerate(SPEC['optional_vehicles']):
        folder=ADDONS/'GameAssets/vehicles'/row['id'];size=sum(p.stat().st_size for p in files(folder))
        sections += ['Section "'+nsis(row['name'])+' ('+f'{size/1e6:.1f}'+' MB)" CAR_'+str(i),'SectionIn 1',payload(files(folder),ADDONS),'SectionEnd']
        descriptions.append('!insertmacro MUI_DESCRIPTION_TEXT ${CAR_'+str(i)+'} "'+nsis(row['name'])+'; optional, unranked, no visible driver."')
        selection += ['SectionSetFlags ${CAR_'+str(i)+'} 0','${StrStr} $R2 $R3 ",'+row['id']+',"','${If} $InstallProfile == "complete"','${OrIf} $CarSelection == "all"','${OrIf} $R2 != ""','SectionSetFlags ${CAR_'+str(i)+'} ${SF_SELECTED}','${EndIf}']
    for name,lines in [('cars',sections),('descriptions',descriptions),('selection',selection)]:
        (ROOT/('installer/release232-'+name+'.nsh')).write_text('\n'.join(lines),encoding='utf-8')
    dump(QA/'payload.json',{'version':'2.3.2','base_files':{p.relative_to(BASE).as_posix():sha(p) for p in files(BASE)},'addon_files':{p.relative_to(ADDONS).as_posix():sha(p) for p in files(ADDONS)}})
    print('RELEASE232_ASSEMBLED core=16 cars, tracks=3, additional=32',flush=True)

def package():
    installer_report=json.loads((QA/'installer.json').read_text(encoding='utf-8'))
    assert installer_report['status']=='PASS' and installer_report['diagnostic_destination_guard']
    assert json.loads((ROOT/'docs/qa-vehicle232/release-content.json').read_text(encoding='utf-8'))['status']=='PASS'
    archive(BASE,OUT/'LeoRacer-2.3.2-win64.zip','LeoRacer')
    archive(ADDONS,OUT/'LeoRacer-AdditionalCars-2.3.2.zip','')
    archive(BASE/'GameAssets/tracks/kandy_lake',OUT/'LeoRacer-KandyLake-2.3.2.zip','GameAssets/tracks/kandy_lake')
    archive(BASE/'GameAssets/vehicles/bigster',OUT/'LeoRacer-Bigster-1.2.1.zip','GameAssets/vehicles/bigster')
    evidence_archive(ROOT/'docs/qa-vehicle232',OUT/'LeoRacer-2.3.2-Evidence.zip','',include_logs=True)
    manifest()

def installer():
    env=os.environ.copy();temporary=ROOT.parent.parent/'t232';temporary.mkdir(exist_ok=True)
    env['TEMP']=env['TMP']=str(temporary)
    with (QA/'installer-build.log').open('w',encoding='utf-8') as output:
        p=subprocess.run([str(ROOT/'.tools/nsis/nsis-3.13/Bin/makensis.exe'),'/V3','installer/SelectableCars232.nsi'],cwd=ROOT,env=env,stdout=output,stderr=subprocess.STDOUT,creationflags=0x08000000,timeout=900)
    assert p.returncode==0,(QA/'installer-build.log').read_text(encoding='utf-8',errors='replace')[-3000:]
    print('INSTALLER232_BUILT', (OUT/'LeoRacer-Setup.exe').stat().st_size,flush=True)

def manifest():
    commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    sizes={'version':'2.3.2','commit':commit,'default_cars':16,'additional_cars':32,'tracks':3,'base_installed_bytes':sum(p.stat().st_size for p in files(BASE)),'additional_installed_bytes':sum(p.stat().st_size for p in files(ADDONS))}
    dump(OUT/'SIZES-2.3.2.json',sizes)
    names=['LeoRacer-Setup.exe','LeoRacer-2.3.2-win64.zip','LeoRacer-AdditionalCars-2.3.2.zip','LeoRacer-KandyLake-2.3.2.zip','LeoRacer-Bigster-1.2.1.zip','LeoRacer-2.3.2-Evidence.zip','ATTRIBUTION-2.3.2.txt','SIZES-2.3.2.json','RELEASE_NOTES-2.3.2.md']
    rows=[{'name':n,'bytes':(OUT/n).stat().st_size,'sha256':sha(OUT/n)} for n in names]
    (OUT/'SHA256SUMS.txt').write_text(''.join(r['sha256']+'  '+r['name']+'\n' for r in rows),encoding='utf-8')
    rows.append({'name':'SHA256SUMS.txt','bytes':(OUT/'SHA256SUMS.txt').stat().st_size,'sha256':sha(OUT/'SHA256SUMS.txt')})
    dump(OUT/'release-manifest.json',{'version':'2.3.2','commit':commit,'files':rows})
    print('RELEASE232_MANIFEST',commit,len(rows),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('target',choices=['assemble','installer','package','manifest']);a=p.parse_args();globals()[a.target]()
