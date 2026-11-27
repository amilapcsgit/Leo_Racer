"""Compile and test the preview installer only inside a verified workspace target."""
from pathlib import Path
import os,subprocess,json,hashlib
import release_260 as release
import verify_distinct as verify
R=release.ROOT;Q=R/'build/qa260';BASE=release.BASE;SETUP=release.OUT/'LeoRacer-Setup.exe'
release.require_gates();release.manifest()
env=dict(os.environ,TEMP=str(Q/'installer-temp'),TMP=str(Q/'installer-temp'));Path(env['TEMP']).mkdir(exist_ok=True)
with (Q/'installer-build.log').open('w',encoding='utf-8') as log:subprocess.run([str(R/'.tools/nsis/nsis-3.13/Bin/makensis.exe'),'/V3','installer/StreamedCars260.nsi'],cwd=R,env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=1200)
dest=R.parent.parent/'i260delivery'
assert dest.resolve().is_relative_to(R.parent.parent.resolve()) and dest.name=='i260delivery' and not dest.exists(),'Preserve prior test installations'
print('VERIFIED_INSTALL_TEST_TARGET',dest,flush=True)
def run(exe,args):subprocess.run([str(exe),*args],cwd=R,env=env,check=True,timeout=900,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
args=['/S','/CONTENTTEST','/TESTDIR='+str(dest),'/D='+str(dest)]
run(SETUP,args)
ids={json.loads(p.read_text(encoding='utf-8'))['id'] for p in (dest/'GameAssets/vehicles').glob('*/vehicle.json')}
assert ids==set(release.content.roster_ids()) and len(ids)==21
assert len(list((dest/'GameAssets/tracks').glob('*/manifest.json')))==3
assert release.sha(dest/'LeoRacer.pck')==release.sha(BASE/'LeoRacer.pck')
verify.QA=Q/'installed';verify.QA.mkdir(exist_ok=True);os.environ['LEO_ASSET_ROOT']=str(dest/'GameAssets')
assert verify.run('content',dest,args=['--verify-content'],vehicles=dest/'GameAssets/vehicles')
custom=dest/'GameAssets/vehicles/my-unmanaged-car/keep.txt';custom.parent.mkdir();custom.write_text('preserve custom content',encoding='utf-8')
readme=dest/'README.txt';readme.write_text('user changed managed note',encoding='utf-8')
run(SETUP,args)
assert custom.read_text(encoding='utf-8')=='preserve custom content'
assert any(p.read_text(encoding='utf-8')=='user changed managed note' for p in (dest/'ContentBackups').rglob('*README.txt'))
readme.write_text('keep on uninstall',encoding='utf-8')
assert dest.resolve().is_relative_to(R.parent.parent.resolve()) and (dest/'Uninstall.exe').is_file()
run(dest/'Uninstall.exe',['/S','/CONTENTTEST','_?='+str(dest)])
assert not (dest/'LeoRacer.exe').exists() and custom.read_text(encoding='utf-8')=='preserve custom content' and readme.read_text(encoding='utf-8')=='keep on uninstall'
release.dump(Q/'installer-full.json',{'status':'PASS','cars':21,'tracks':3,'core_sha256':release.sha(BASE/'LeoRacer.pck'),'installer_sha256':release.sha(SETUP),'fresh_discovery':True,'reinstall_backup':True,'uninstall_preservation':True})
print('INSTALLER260_FULL_PASS',flush=True)
