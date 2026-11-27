"""Close final validation and delivery after the native smoke batch completes."""
from pathlib import Path
import hashlib,json,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[1]
QA=ROOT/'build/distinct'
with (ROOT/'build/Distinct-v3-final/LeoRacer.pck').open('rb') as stream:expected=hashlib.file_digest(stream,'sha256').hexdigest()
deadline=time.monotonic()+300
while True:
    try:
        report=json.loads((QA/'packaged-acceptance.json').read_text(encoding='utf-8'))
        if report.get('candidate_pck_sha256')==expected:
            assert report['status']=='PASS','Native executable acceptance failed'
            break
    except (FileNotFoundError,json.JSONDecodeError):pass
    if time.monotonic()>deadline:raise TimeoutError('Waiting for current executable smoke tests')
    time.sleep(2)
print('Current executable smoke tests PASS',flush=True)
performance=json.loads((QA/'performance-acceptance.json').read_text(encoding='utf-8'))
if performance.get('status')!='PASS' or performance.get('candidate_pck_sha256')!=expected:
    with (QA/'performance-v3-camera-final.log').open('w',encoding='utf-8') as log:
        subprocess.run([sys.executable,'tools/verify_distinct.py','performance-candidates'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
for arguments in [['tools/write_v3_report.py'],['tools/deliver_v3.py','2'],['tools/deliver_v3.py','3'],['tools/package_distinct.py','package']]:
    subprocess.run([sys.executable,*arguments],cwd=ROOT,check=True)
print('V3_FINAL_DELIVERY PASS',flush=True)
