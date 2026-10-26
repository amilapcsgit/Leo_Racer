"""Verify the delivered ZIP, then run its self-contained Windows executable."""
from pathlib import Path
import json,os,subprocess,zipfile
from candidate_232 import ROOT,BASE,OUT,QA,dump,archive
from report_vehicle232 import sha

def main():
    manifest=json.loads((OUT/'manifest.json').read_text())
    for row in manifest['files']:assert sha(OUT/row['name'])==row['sha256'],row['name']
    destination=ROOT/'build/x232';destination.mkdir(parents=True,exist_ok=True)
    assert destination.resolve().is_relative_to((ROOT/'build').resolve())
    with zipfile.ZipFile(OUT/'LeoRacer-2.3.2-test-win64.zip') as z:
        assert z.testzip() is None
        for name in z.namelist():
            assert not Path(name).is_absolute() and '..' not in Path(name).parts
        z.extractall(destination)
    folder=destination/'LeoRacer'
    hashes={p.relative_to(folder).as_posix():sha(p) for p in folder.rglob('*') if p.is_file()}
    assert all(value==sha(BASE/name) for name,value in hashes.items())
    assert len(list((folder/'GameAssets/vehicles').glob('*/vehicle.json')))==16
    results=[]
    for label,args in [('zip-content',['--verify-content']),('zip-boot-art',['--verify-boot-art']),('zip-cameras',['--vehicle-check=cameras'])]:
        env=os.environ.copy();profile=QA/'profiles'/label;profile.mkdir(parents=True,exist_ok=True)
        env['APPDATA']=str(profile);env['LOCALAPPDATA']=str(profile)
        env['DOTNET_ROOT']=str(profile/'no-sdk-installed');env['DOTNET_MULTILEVEL_LOOKUP']='0'
        env['PATH']=os.pathsep.join(part for part in env.get('PATH','').split(os.pathsep) if 'dotnet' not in part.lower())
        env['VEHICLE_QA_OUTPUT']=str(ROOT/'docs/qa-vehicle232'/label)
        log=QA/(label+'.log')
        with log.open('w',encoding='utf-8') as f:
            process=subprocess.Popen([str(folder/'LeoRacer.console.exe'),'--headless','--','--drive-test',*args],env=env,cwd=folder,stdout=f,stderr=subprocess.STDOUT)
            code=process.wait(timeout=180)
        text=log.read_text(encoding='utf-8',errors='replace')
        assert code==0 and 'SCRIPT ERROR' not in text and 'CONTENT_VALIDATION_FAILED' not in text,(label,code,text[-1000:])
        if label=='zip-content':assert 'CONTENT_VALIDATION_OK' in text
        if label=='zip-boot-art':assert '"status":"PASS"' in text
        if label=='zip-cameras':assert '"status":"PASS"' in text and 'VEHICLE_CAMERA_TEST' in text
        results.append({'label':label,'exit_code':code,'sdk_on_path':False})
        (ROOT/'docs/qa-vehicle232'/log.name).write_text(text,encoding='utf-8')
        print('EXTRACTED_CHECK_PASS',label,flush=True)
    report={'status':'PASS','archive_crc':True,'member_hashes_match':True,'files':len(hashes),'default_vehicles':16,'self_contained_runtime':True,'checks':results,'exe_sha256':hashes['LeoRacer.exe'],'core_sha256':hashes['LeoRacer.pck']}
    dump(ROOT/'docs/qa-vehicle232/extracted-package.json',report)
    print('EXTRACTED_PACKAGE_PASS',json.dumps(report),flush=True)

if __name__=='__main__':main()
