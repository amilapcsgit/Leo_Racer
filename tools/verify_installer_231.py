"""Clean install and actual 2.3.0-to-2.3.1 upgrade in isolated workspace folders."""
from pathlib import Path
import argparse,json,os,subprocess
from release_231 import ROOT,BASE,OUT,SPEC,dump
WORK=ROOT/'build/kandy231';DEST=ROOT.parent.parent/'t'
def install(setup,folder,cars=''):
    env=os.environ.copy();env['TEMP']=env['TMP']=str(WORK/'temp')
    result=subprocess.run([str(setup),'/S','/CONTENTTEST','/CARS='+cars,'/D='+str(folder)],env=env,cwd=ROOT,timeout=600)
    assert result.returncode==0,('installer',result.returncode)
    assert (folder/'LeoRacer.exe').is_file()
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--suffix',default='');args=parser.parse_args()
    assert not args.suffix or args.suffix.isalnum()
    prefix='231'+('-'+args.suffix if args.suffix else '')
    setup=OUT/'LeoRacer-Setup-2.3.1.exe';old=ROOT/'dist/release-2.3.0/LeoRacer-Setup-2.3.0.exe'
    clean=DEST/(prefix+'-clean');upgrade=DEST/(prefix+'-upgrade')
    assert not clean.exists() and not upgrade.exists(),'Test folders already exist; preserve and inspect them before reuse'
    install(setup,clean)
    assert len(list((clean/'GameAssets/vehicles').glob('*/vehicle.json')))==16
    install(old,upgrade,SPEC['optional_vehicles'][0]['id'])
    custom=upgrade/'GameAssets/vehicles/my_custom_car';custom.mkdir();(custom/'keep.txt').write_text('preserve my car',encoding='utf-8')
    changed=upgrade/'GameAssets/tracks/kandy_lake/LICENSE.txt';changed.write_text('my attribution annotation',encoding='utf-8')
    profile=WORK/'upgrade-user-data';profile.mkdir(exist_ok=True);(profile/'leo_racer.cfg').write_text('[display]\nreduced_motion=true\n',encoding='utf-8');(profile/'records.sqlite3').write_bytes(b'isolated-records-preservation-marker')
    install(setup,upgrade)
    assert (custom/'keep.txt').read_text(encoding='utf-8')=='preserve my car'
    assert len(list((upgrade/'GameAssets/vehicles').glob('*/vehicle.json')))==17
    assert any(p.read_text(encoding='utf-8')=='my attribution annotation' for p in (upgrade/'ContentBackups').rglob('*LICENSE.txt'))
    assert (profile/'records.sqlite3').read_bytes()==b'isolated-records-preservation-marker'
    assert 'reduced_motion=true' in (profile/'leo_racer.cfg').read_text(encoding='utf-8')
    for folder in [clean,upgrade]:
        env=os.environ.copy();env['APPDATA']=str(profile)
        result=subprocess.run([str(folder/'LeoRacer.console.exe'),'--headless','--','--verify-content'],cwd=folder,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=90)
        log=result.stdout+result.stderr;(WORK/(folder.name+'-installed.log')).write_text(log,encoding='utf-8');assert result.returncode==0 and 'CONTENT_VALIDATION_OK' in log,log[-1500:]
    dump(WORK/'installer.json',{'status':'PASS','clean_defaults':16,'upgrade_cars':17,'custom_car_preserved':True,'modified_track_backed_up':True,'isolated_profile_markers_preserved':True,'installed_content_verified':True})
    print('INSTALLER_231_PASS')
if __name__=='__main__':main()
