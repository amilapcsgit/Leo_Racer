"""Exercise fresh install, replacement backup, uninstall and portable extraction."""
import json, os, subprocess, zipfile
from pathlib import Path
from package_ultra import BASE, OUT, QA, ROOT, sha, dump
from run_ultra_checks import run

def verify():
    target=ROOT.parent.parent/'i270delivery'
    assert target.resolve().is_relative_to(ROOT.parent.parent.resolve()) and not target.exists(), 'Preserve prior installation tests'
    test_temp=ROOT.parent.parent/'t270-install'
    assert test_temp.resolve().is_relative_to(ROOT.parent.parent.resolve()) and not test_temp.exists(), 'Preserve prior installer temporary files'
    test_temp.mkdir()
    env=dict(os.environ,TEMP=str(test_temp),TMP=str(test_temp))
    setup=OUT/'LeoRacer-Setup.exe'
    def execute(exe,args):
        subprocess.run([str(exe),*args],cwd=ROOT,env=env,check=True,timeout=900,creationflags=subprocess.CREATE_NO_WINDOW)
    args=['/S','/CONTENTTEST','/TESTDIR='+str(target),'/D='+str(target)]
    execute(setup,args)
    assert len(list((target/'GameAssets/vehicles').glob('*/vehicle.json')))==21
    assert len(list((target/'GameAssets/tracks').glob('*/manifest.json')))==3
    assert sha(target/'LeoRacer.pck')==sha(BASE/'LeoRacer.pck')
    assert run('core',export=target)
    custom=target/'GameAssets/vehicles/my-unmanaged-car/keep.txt';custom.parent.mkdir();custom.write_text('preserve custom content',encoding='utf-8')
    note=target/'README.txt';note.write_text('user changed managed note',encoding='utf-8')
    execute(setup,args)
    assert custom.read_text(encoding='utf-8')=='preserve custom content'
    assert any(p.read_text(encoding='utf-8')=='user changed managed note' for p in (target/'ContentBackups').rglob('*README.txt'))
    note.write_text('keep on uninstall',encoding='utf-8')
    assert target.resolve().is_relative_to(ROOT.parent.parent.resolve()) and (target/'Uninstall.exe').is_file()
    execute(target/'Uninstall.exe',['/S','/CONTENTTEST','_?='+str(target)])
    assert not (target/'LeoRacer.exe').exists() and custom.read_text(encoding='utf-8')=='preserve custom content' and note.read_text(encoding='utf-8')=='keep on uninstall'
    portable=ROOT/'build/portable270-verified'
    assert not portable.exists(), 'Preserve prior portable tests'
    with zipfile.ZipFile(OUT/'LeoRacer-2.7.0-win64.zip') as archive:archive.extractall(portable)
    extracted=portable/'LeoRacer'
    assert sha(extracted/'LeoRacer.pck')==sha(BASE/'LeoRacer.pck')
    assert run('core',export=extracted)
    dump(QA/'delivery.json',{'status':'PASS','cars':21,'tracks':3,'core_sha256':sha(BASE/'LeoRacer.pck'),'installer_sha256':sha(setup),'portable_sha256':sha(OUT/'LeoRacer-2.7.0-win64.zip'),'fresh_install':True,'reinstall_backup':True,'uninstall_preservation':True,'portable_extraction':True,'sdk_removed':True})
    print('ULTRA_DELIVERY_PASS',flush=True)

if __name__=='__main__':verify()
