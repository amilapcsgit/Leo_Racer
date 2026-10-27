"""Assemble the user-authorized twenty-car offline release; gate publication on evidence."""
from pathlib import Path
import argparse,json,os,shutil,subprocess,zipfile,sys
from release_231 import payload,files
from quality25 import ROOT,QA as LOCAL,verify_roster,sha,dump
SOURCE=ROOT/'build/Quality25-release-fixed'
BASE=ROOT/'build/Release-2.5.0'
QA=ROOT/'build/release250'
OUT=ROOT/'dist/release-2.5.0'

def prepare():
    assert not BASE.exists(),'Preserve existing public staging before rebuilding'
    verify_roster(SOURCE/'GameAssets/vehicles')
    BASE.mkdir(parents=True);OUT.mkdir(parents=True,exist_ok=True);QA.mkdir(parents=True,exist_ok=True)
    for name in ['LeoRacer.exe','LeoRacer.console.exe','LeoRacer.pck','data_LeoRacer_windows_x86_64','GameAssets','Tools','Vehicle Workshop.cmd','default-roster-v1.json']:
        src=SOURCE/name
        if src.is_dir():shutil.copytree(src,BASE/name)
        else:shutil.copy2(src,BASE/name)
    for src in SOURCE.glob('*.dll'):shutil.copy2(src,BASE/src.name)
    assert sha(BASE/'LeoRacer.pck')==sha(SOURCE/'LeoRacer.pck')
    verify_roster(BASE/'GameAssets/vehicles')
    shutil.copy2(ROOT/'installer/InstallerContent.ps1',BASE/'InstallerContent.ps1')
    shutil.copy2(ROOT/'docs/QUALITY25.md',BASE/'TEST_REPORT.md')
    (BASE/'README.txt').write_text('LEO RACER 2.5.0\n\nRun LeoRacer.exe. Includes the selected 20 tested cars and all three tracks.\nNo Godot, SDK, account or download required. Use Play Compatibility.cmd if Vulkan is unavailable.\nExisting add-ons and saved records remain supported. Imports remain modded/unranked.\nNew records use distinct_v4. See TEST_REPORT.md for measured validation and limitations.\nAttribution: GameAssets/licenses and each vehicle LICENSE.txt.\n',encoding='utf-8')
    (BASE/'Play Compatibility.cmd').write_text('@echo off\ncd /d "%~dp0"\nstart "" "LeoRacer.exe" --rendering-method gl_compatibility --rendering-driver opengl3\n',encoding='ascii')
    confirmation=json.loads((ROOT/'content/releases/2.3.1.json').read_text())['redistribution_confirmation']
    dump(BASE/'GameAssets/licenses/Imported-cars-permission.json',confirmation)
    dump(BASE/'release-build.json',{'version':'2.5.0','branch':'release/2.5.0','default_vehicles':20,'tracks':3,'imports_included':13,'tested_core_sha256':sha(BASE/'LeoRacer.pck')})
    compile_installer()

def compile_installer():
    shutil.copy2(ROOT/'installer/InstallerContent.ps1',BASE/'InstallerContent.ps1')
    shutil.copy2(ROOT/'docs/QUALITY25.md',BASE/'TEST_REPORT.md')
    script=(ROOT/'installer/OfficialCars241.nsi').read_text(encoding='utf-8').replace('2.4.1','2.5.0').replace('release241-','release250-').replace('16 official cars','20 tested cars').replace('16 cars','20 cars').replace('16 default cars','20 default cars').replace('original 16 vehicles','selected 20 vehicles')
    (ROOT/'installer/FocusedCars250.nsi').write_text(script,encoding='utf-8')
    tracks=json.loads((ROOT/'content/releases/2.3.2.json').read_text())['tracks']
    dump(BASE/'required-payload.json',{'files':{p.relative_to(BASE).as_posix():sha(p) for p in files(BASE) if p.name!='required-payload.json' and not p.relative_to(BASE).as_posix().startswith('GameAssets/tracks/')}})
    for suffix in ['required','tracks','descriptions','selection']:
        if suffix=='required':text=payload([p for p in files(BASE) if not p.relative_to(BASE).as_posix().startswith('GameAssets/tracks/')],BASE)
        elif suffix=='tracks':text='\n'.join('Section "'+row['name']+'" TRACK_'+str(i)+'\nSectionIn 1 2\n'+payload(files(BASE/'GameAssets/tracks'/row['id']),BASE)+'SectionEnd' for i,row in enumerate(tracks))
        elif suffix=='descriptions':text='\n'.join('!insertmacro MUI_DESCRIPTION_TEXT ${TRACK_'+str(i)+'} "'+row['name']+'; solo and split-screen."' for i,row in enumerate(tracks))
        else:
            lines=['StrCpy $R3 ",$TrackSelection,"']
            for i,row in enumerate(tracks):lines+=['SectionSetFlags ${TRACK_'+str(i)+'} 0','${StrStr} $R2 $R3 ",'+row['id']+',"','${If} $TrackSelection == "all"','${OrIf} $R2 != ""','SectionSetFlags ${TRACK_'+str(i)+'} ${SF_SELECTED}','${EndIf}']
            text='\n'.join(lines)
        (ROOT/('installer/release250-'+suffix+'.nsh')).write_text(text,encoding='utf-8')
    env=os.environ.copy();temp=QA/'temp';temp.mkdir(exist_ok=True);env['TEMP']=env['TMP']=str(temp)
    with (QA/'installer-build.log').open('w',encoding='utf-8') as log:
        subprocess.run([str(ROOT/'.tools/nsis/nsis-3.13/Bin/makensis.exe'),'/V3','installer/FocusedCars250.nsi'],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=1200)
    print('PUBLIC250_PREPARED',sha(BASE/'LeoRacer.pck'),flush=True)

def smoke():
    import verify_distinct as v
    results=[]
    cases=[('content',['--verify-content'],False,False),('forward',['--vehicle-check=cameras'],True,False),('compatibility',['--vehicle-check=cameras'],True,True)]
    cases += [(track+'-'+mode,['--track='+track,'--track-check='+mode],False,False) for track in ['astra_coast','colombo_city','kandy_lake'] for mode in ['single','split']]
    for label,args,render,compat in cases:
        ok=v.run('public250-'+label,BASE,args=args,render=render,compat=compat,vehicles=BASE/'GameAssets/vehicles')
        results.append({'case':label,'pass':ok});assert ok,results[-1]
    dump(QA/'smoke.json',{'status':'PASS','cases':results,'cars':20,'core_sha256':sha(BASE/'LeoRacer.pck')})

def installer():
    suffix=os.environ.get('LEO_INSTALLER_TEST_SUFFIX','verified');assert suffix.isalnum()
    dest=ROOT.parent.parent/('i250'+suffix);assert not dest.exists(),'Keep prior test installation for inspection'
    env=os.environ.copy();temp=Path(env['USERPROFILE'])/'AppData/Local/Temp/LeoRacer250';temp.mkdir(parents=True,exist_ok=True);env['TEMP']=env['TMP']=str(temp)
    setup=OUT/'LeoRacer-Setup.exe'
    def run(exe,args):subprocess.run([str(exe),*args],cwd=ROOT,env=env,check=True,timeout=900)
    args=['/S','/CONTENTTEST','/TESTDIR='+str(dest),'/D='+str(dest)]
    run(setup,args);verify_roster(dest/'GameAssets/vehicles')
    assert len(list((dest/'GameAssets/tracks').glob('*/manifest.json')))==3
    assert sha(dest/'LeoRacer.pck')==sha(BASE/'LeoRacer.pck')
    import verify_distinct as v
    assert v.run('installed250-content',dest,args=['--verify-content'],vehicles=dest/'GameAssets/vehicles')
    custom=dest/'GameAssets/vehicles/custom-marker/keep.txt';custom.parent.mkdir();custom.write_text('preserve personal content')
    changed=dest/'README.txt';changed.write_text('user modified note')
    run(setup,args)
    assert custom.read_text()=='preserve personal content'
    assert any(p.read_text(encoding='utf-8')=='user modified note' for p in (dest/'ContentBackups').rglob('*README.txt'))
    changed.write_text('keep on uninstall')
    run(dest/'Uninstall.exe',['/S','/CONTENTTEST','_?='+str(dest)])
    assert not (dest/'LeoRacer.exe').exists() and custom.read_text()=='preserve personal content' and changed.read_text()=='keep on uninstall'
    dump(QA/'installer.json',{'status':'PASS','cars':20,'tracks':3,'core_sha256':sha(BASE/'LeoRacer.pck'),'installer_sha256':sha(setup),'installed_content_verified':True,'reinstall_preserves_custom':True,'modified_backup':True,'uninstall_preserves_custom_and_modified':True})
    print('INSTALLER250_PASS',flush=True)

def package():
    for name in ['smoke','installer']:assert json.loads((QA/(name+'.json')).read_text())['status']=='PASS'
    tested=json.loads((QA/'smoke.json').read_text());performance=json.loads((LOCAL/'performance-acceptance.json').read_text());installed=json.loads((QA/'installer.json').read_text())
    assert performance['status']=='PASS'
    assert tested['core_sha256']==performance['candidate_core_sha256']==installed['core_sha256']==sha(BASE/'LeoRacer.pck')==sha(SOURCE/'LeoRacer.pck')
    assert installed['installer_sha256']==sha(OUT/'LeoRacer-Setup.exe')
    verify_roster(BASE/'GameAssets/vehicles')
    shutil.copy2(ROOT/'docs/QUALITY25.md',OUT/'TEST_REPORT.md')
    shutil.copy2(ROOT/'docs/RELEASE_NOTES_250.md',OUT/'RELEASE_NOTES-2.5.0.md')
    with zipfile.ZipFile(OUT/'LeoRacer-2.5.0-win64.zip','w',zipfile.ZIP_DEFLATED,compresslevel=4) as archive:
        for path in files(BASE):archive.write(path,'LeoRacer/'+path.relative_to(BASE).as_posix())
    with zipfile.ZipFile(OUT/'LeoRacer-2.5.0-win64.zip') as archive:assert archive.testzip() is None
    with zipfile.ZipFile(OUT/'LeoRacer-2.5.0-Evidence.zip','w',zipfile.ZIP_DEFLATED) as archive:
        for name in ['smoke.json','installer.json','payload-guard.json']:
            archive.write(QA/name,'public/'+name)
        for name in ['performance-acceptance.json','Quality25-release-fixed-package.json']:
            archive.write(LOCAL/name,name)
        for name in ['q25-features-final/features.json','q25-audit-final/audit.json','q25-regression-final/acceptance.json','q25-contacts-final/contacts.json','q25-framing/framing.json','q25-pace/pace.json','q25-races/races.json']:
            archive.write(ROOT/'build/distinct'/name,name)
        for path in (LOCAL/'performance').rglob('*.json'):
            if 'profile' not in path.parts:archive.write(path,'performance/'+path.relative_to(LOCAL/'performance').as_posix())
        for name in ['Kandy-contact-forward.gif','Kandy-contact-compatibility.gif','README.txt']:
            archive.write(LOCAL/'evidence'/name,'contact-fixture/'+name)
        for path in (ROOT/'docs/screenshots/2.5.0').glob('*.png'):
            if 'promotional' not in path.name:archive.write(path,'gameplay/'+path.name)
    assets=['LeoRacer-Setup.exe','LeoRacer-2.5.0-win64.zip','LeoRacer-2.5.0-Evidence.zip','TEST_REPORT.md','RELEASE_NOTES-2.5.0.md']
    rows=[{'name':name,'bytes':(OUT/name).stat().st_size,'sha256':sha(OUT/name)} for name in assets]
    (OUT/'SHA256SUMS.txt').write_text(''.join(row['sha256']+'  '+row['name']+'\n' for row in rows),encoding='utf-8')
    rows.append({'name':'SHA256SUMS.txt','bytes':(OUT/'SHA256SUMS.txt').stat().st_size,'sha256':sha(OUT/'SHA256SUMS.txt')})
    dump(OUT/'release-manifest.json',{'version':'2.5.0','commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'cars':20,'tracks':3,'files':rows})
    print('PACKAGE250_READY',flush=True)

def publish():
    subprocess.run([sys.executable,str(ROOT/'tools/publish_content_release.py'),'--manifest',str(OUT/'release-manifest.json'),'--notes',str(ROOT/'docs/RELEASE_NOTES_250.md'),'--title','Leo Racer 2.5.0 — 20 cars, polished tracks and convincing collisions','--publish'],cwd=ROOT,check=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['prepare','compile_installer','smoke','installer','package','publish']);args=parser.parse_args();globals()[args.action]()
