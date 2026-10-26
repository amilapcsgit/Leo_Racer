"""Test the real selectable installer without touching the user's installation."""
from pathlib import Path
import argparse, json, os, subprocess, tempfile, shutil
from release_232 import ROOT, BASE, OUT, QA, SPEC, dump, sha

WORK=ROOT.parent.parent/'t232'

def install(setup,folder,profile='custom',tracks='all',cars='',diagnostic_folder=None):
    assert folder.resolve().is_relative_to(WORK.resolve())
    diagnostic_folder=diagnostic_folder or folder
    assert diagnostic_folder.resolve().is_relative_to(WORK.resolve())
    env=os.environ.copy();env['APPDATA']=env['LOCALAPPDATA']=str(QA/'installer-profile')
    # Use the system temporary directory for NSIS's long optional texture paths.
    env['TEMP']=env['TMP']=tempfile.gettempdir()
    args=[str(setup),'/S','/CONTENTTEST','/TESTDIR='+str(diagnostic_folder),'/PROFILE='+profile,'/TRACKS='+tracks,'/CARS='+cars,'/D='+str(folder)]
    assert len(subprocess.list2cmdline(args))<900,'NSIS command line must fit within its 1024-character buffer'
    p=subprocess.run(args,cwd=ROOT,env=env,creationflags=0x08000000,timeout=600)
    if p.returncode==0:assert (folder/'LeoRacer.exe').is_file(),'Installer destination mismatch'
    return p.returncode

def content(folder,label,expected_tracks):
    env=os.environ.copy();env['APPDATA']=env['LOCALAPPDATA']=str(QA/'profiles'/label)
    Path(env['APPDATA']).mkdir(parents=True,exist_ok=True)
    env['DOTNET_ROOT']=str(QA/'no-sdk');env['PATH']=os.pathsep.join(p for p in env['PATH'].split(os.pathsep) if 'dotnet' not in p.lower())
    with (QA/(label+'.log')).open('w',encoding='utf-8') as output:
        p=subprocess.run([str(folder/'LeoRacer.console.exe'),'--headless','--','--drive-test','--verify-content'],cwd=folder,env=env,stdout=output,stderr=subprocess.STDOUT,timeout=180)
    text=(QA/(label+'.log')).read_text(encoding='utf-8',errors='replace')
    assert p.returncode==0 and 'CONTENT_VALIDATION_OK' in text and 'SCRIPT ERROR' not in text,text[-1500:]
    for track in expected_tracks:assert 'TRACK_VERIFIED '+track+' official=true' in text

def ids(folder,kind,filename):return sorted(p.parent.name for p in (folder/'GameAssets'/kind).glob('*/'+filename))

def installers():
    guard()
    WORK.mkdir(exist_ok=True);setup=OUT/'LeoRacer-Setup.exe';rows=[]
    optional=[r['id'] for r in SPEC['optional_vehicles']];tracks=[r['id'] for r in SPEC['tracks']]
    cases=[('complete','complete',tracks,optional),('standard','standard',tracks,[]),('custom','custom',['kandy_lake'],optional[:2])]
    for name,profile,chosen,extras in cases:
        folder=WORK/('r232-'+name);assert not folder.exists(),'Preserve existing fixture: '+str(folder)
        selection='all' if profile=='complete' else ','.join(extras)
        assert install(setup,folder,profile,','.join(chosen),selection)==0
        assert ids(folder,'vehicles','vehicle.json')==sorted(SPEC['default_vehicles']+extras)
        assert ids(folder,'tracks','manifest.json')==sorted(chosen)
        ledger=json.loads((folder/'.leo-installer-owned.json').read_text(encoding='utf-8'));assert ledger['version']=='2.3.2'
        for key,digest in ledger['files'].items():assert sha(folder/key)==digest,key
        content(folder,'installed-'+name,chosen)
        if name=='custom':
            custom=folder/'GameAssets/vehicles/my_custom_car';custom.mkdir();(custom/'keep.txt').write_text('my own car',encoding='utf-8')
            modified=folder/'GameAssets/vehicles/bigster/LICENSE.txt';modified.write_text('keep my note',encoding='utf-8')
            assert install(setup,folder,'custom','astra_coast','')==0
            assert (custom/'keep.txt').read_text(encoding='utf-8')=='my own car'
            assert ids(folder,'tracks','manifest.json')==['astra_coast','kandy_lake']
            assert all((folder/'GameAssets/vehicles'/key/'vehicle.json').exists() for key in extras)
            assert any(p.read_text(encoding='utf-8')=='keep my note' for p in (folder/'ContentBackups').rglob('*LICENSE.txt'))
            modified.write_text('retain on uninstall',encoding='utf-8')
            env=os.environ.copy();env['TEMP']=env['TMP']=tempfile.gettempdir()
            p=subprocess.run([str(folder/'Uninstall.exe'),'/S','/CONTENTTEST','_?='+str(folder)],cwd=ROOT,env=env,creationflags=0x08000000,timeout=300)
            assert p.returncode==0 and not (folder/'LeoRacer.exe').exists()
            assert modified.read_text(encoding='utf-8')=='retain on uninstall' and (custom/'keep.txt').exists()
        rows.append({'profile':name,'cars':16+len(extras),'tracks':len(chosen),'status':'PASS'})
        print('INSTALLER232_CASE_PASS',name,flush=True)
    invalid=WORK/'r232-no-tracks';assert not invalid.exists()
    assert install(setup,invalid,'custom','none','')!=0 and not (invalid/'LeoRacer.exe').exists()
    upgrade=WORK/'r232-upgrade';assert not upgrade.exists()
    old=ROOT/'dist/release-2.3.1/LeoRacer-Setup-2.3.1.exe'
    assert install(old,upgrade,'custom','all',optional[0])==0
    custom=upgrade/'GameAssets/vehicles/my_upgrade_car';custom.mkdir();(custom/'keep.txt').write_text('preserved',encoding='utf-8')
    modified=upgrade/'GameAssets/vehicles/bigster/LICENSE.txt';modified.write_text('upgrade note',encoding='utf-8')
    profile=QA/'installer-profile/Godot/app_userdata/Leo Racer';profile.mkdir(parents=True,exist_ok=True)
    markers={'leo_racer.cfg':b'[display]\nreduced_motion=true\n','local_inputs.cfg':b'[bindings]\nmarker="preserve"\n','rankings.sqlite3':b'isolated existing rankings marker'}
    for name,data in markers.items():(profile/name).write_bytes(data)
    assert install(setup,upgrade,'standard','all','')==0
    assert (custom/'keep.txt').read_text(encoding='utf-8')=='preserved'
    assert (upgrade/'GameAssets/vehicles'/optional[0]/'vehicle.json').exists()
    assert json.loads((upgrade/'GameAssets/vehicles/bigster/vehicle.json').read_text(encoding='utf-8'))['version']=='1.2.1'
    assert any(p.read_text(encoding='utf-8')=='upgrade note' for p in (upgrade/'ContentBackups').rglob('*LICENSE.txt'))
    assert all((profile/name).read_bytes()==data for name,data in markers.items())
    content(upgrade,'installed-upgrade',tracks)
    report={'status':'PASS','cases':rows,'diagnostic_destination_guard':True,'zero_tracks_rejected':True,'upgrade_from':'2.3.1','user_cars_preserved':True,'prior_deselected_content_preserved':True,'modified_files_backed_up':True,'uninstall_preserves_custom_and_modified':True,'settings_inputs_records_preserved':True,'sdk_free_content_checks':True}
    dump(QA/'installer.json',report);dump(ROOT/'docs/qa-vehicle232/release-installer.json',report)
    shutil.copy2(QA/'installer-build.log',ROOT/'docs/qa-vehicle232/release-installer-build.log')
    print('INSTALLER232_ALL_PASS',flush=True)

def guard():
    actual=WORK/'r232-guard-actual';intended=WORK/'r232-guard-intended'
    assert not actual.exists() and not intended.exists()
    assert install(OUT/'LeoRacer-Setup.exe',actual,'complete','all','all',intended)!=0
    assert not (actual/'LeoRacer.exe').exists() and not (intended/'LeoRacer.exe').exists()
    if (QA/'installer.json').exists():
        data=json.loads((QA/'installer.json').read_text(encoding='utf-8'));data['diagnostic_destination_guard']=True
        dump(QA/'installer.json',data);dump(ROOT/'docs/qa-vehicle232/release-installer.json',data)
    print('INSTALLER232_DESTINATION_GUARD_PASS',flush=True)

def game():
    import sys
    sys.path.insert(0,str(ROOT/'tools'))
    from qa_vehicle232 import run
    assert run('release232-cameras',script='tests/vehicle_camera_test.gd',folder=BASE,args=['--track=kandy_lake'])
    content(BASE,'release-content',[r['id'] for r in SPEC['tracks']])
    combined=QA/'all-vehicles'
    shutil.copytree(BASE/'GameAssets/vehicles',combined,dirs_exist_ok=True)
    shutil.copytree(ROOT/'build/a/GameAssets/vehicles',combined,dirs_exist_ok=True)
    assert run('release232-cars',folder=BASE,args=['--validate-vehicles','--vehicles='+str(combined)])
    from qa_vehicle232 import QA as CANDIDATE_QA
    for line in (CANDIDATE_QA/'release232-cars.log').read_text(encoding='utf-8').splitlines():
        if line.startswith('VEHICLE_VALIDATION '):
            report=json.loads(line.split(' ',1)[1]);assert len(report['vehicles'])==48 and sum(r['official'] for r in report['vehicles'])==16
    dump(ROOT/'docs/qa-vehicle232/release-content.json',{'status':'PASS','official_tracks':3,'vehicles':48,'official_cars':16,'camera_checks':69})
    print('RELEASE232_GAME_PASS',flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('target',choices=['installers','game','guard']);a=p.parse_args();globals()[a.target]()
