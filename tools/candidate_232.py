"""Local v2.3.2 test-build delivery. Does not publish or modify an installation."""
from pathlib import Path
import argparse,hashlib,json,shutil,subprocess,zipfile
import content
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'build/Release-2.3.2'
OUT=ROOT/'dist/vehicle-2.3.2-test'
QA=ROOT/'build/vehicle232'

def dump(path,data):path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
def prepare(baseline):
    assert baseline.resolve()!=BASE.resolve() and (baseline/'LeoRacer.exe').is_file()
    shutil.copytree(baseline,BASE,dirs_exist_ok=True)
    content.vehicle('bigster',BASE/'GameAssets/vehicles',QA/'vehicles/bigster')
    shutil.copy2(QA/'vehicles/bigster/feature-authoring.json',BASE/'GameAssets/vehicles/bigster/feature-authoring.json')
    print('CANDIDATE_PREPARED',BASE,flush=True)
def finish(baseline):
    # Tracks and route revisions remain the verified v2.3.1 packages.
    for name in ['astra_coast','colombo_city','kandy_lake']:
        shutil.copytree(baseline/'GameAssets/tracks'/name,BASE/'GameAssets/tracks'/name,dirs_exist_ok=True)
    content.vehicle('bigster',BASE/'GameAssets/vehicles',QA/'vehicles/bigster')
    (BASE/'README.txt').write_text('LEO RACER 2.3.2 — WINDOWS TEST BUILD\n\nExtract the complete ZIP into its own folder and run LeoRacer.exe.\nAutomatic brake and reverse lamps; L headlights; O sunroof; K second action (Bigster: unassigned).\nC holds Look Back. Right-mouse drag or right stick orbits. Reverse travel automatically turns the camera.\nGamepad: D-pad Left headlights, Up Action 1, Down Action 2, Right Stick Click Look Back.\nAll gamepad/keyboard actions can be changed in Controls.\nContent > Vehicles > Set Up Vehicle configures portable lamp surfaces, anchors and feature animations.\nShared keyboard P2 uses Numpad 1/2/3/0 for these new buttons; they are remappable.\nOriginal profiles and records use their existing location. Older assignments take precedence over new defaults.\nIncludes the same 16 default cars and three tracks as 2.3.1. Existing optional car folders remain compatible.\nThis is a local test candidate; original source downloads and the current installation were not edited.\nSee TEST_REPORT.md and GameAssets/licenses for validation and attribution.\n',encoding='utf-8')
    dump(BASE/'candidate-build.json',{'version':'2.3.2','bigster_package':'1.2.1','public_release':False,'baseline':'2.3.1','source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'working_tree':True,'vehicles':16,'tracks':3})
    print('CANDIDATE_ASSEMBLED',flush=True)
def archive(folder,path,prefix,include_logs=False):
    with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED,compresslevel=4) as z:
        for p in sorted(folder.rglob('*')):
            if p.is_file() and p.suffix!='.pdb' and (include_logs or p.suffix!='.log') and not p.name.startswith('.') and p.name not in ['ui-smoke.json','libterrain.windows.debug.x86_64.dll']:
                z.write(p,(Path(prefix)/p.relative_to(folder)).as_posix())
    with zipfile.ZipFile(path) as z:assert z.testzip() is None
def package():
    OUT.mkdir(parents=True,exist_ok=True)
    report=ROOT/'docs/qa-vehicle232/TEST_REPORT.md'
    assert report.is_file()
    shutil.copy2(report,BASE/'TEST_REPORT.md');shutil.copy2(report,OUT/'TEST_REPORT.md')
    shutil.copy2(ROOT/'docs/VEHICLE_FEATURES.md',BASE/'VEHICLE_FEATURES.md');shutil.copy2(ROOT/'docs/VEHICLE_FEATURES.md',OUT/'VEHICLE_FEATURES.md')
    correction=ROOT/'docs/qa-vehicle232/LIGHTING_CORRECTION.md'
    if correction.exists():
        shutil.copy2(correction,BASE/correction.name);shutil.copy2(correction,OUT/correction.name)
    archive(BASE,OUT/'LeoRacer-2.3.2-test-win64.zip','LeoRacer')
    archive(BASE/'GameAssets/vehicles/bigster',OUT/'LeoRacer-Bigster-1.2.1.zip','GameAssets/vehicles/bigster')
    archive(ROOT/'docs/qa-vehicle232',OUT/'LeoRacer-2.3.2-evidence.zip','',include_logs=True)
    rows=[]
    for p in sorted(OUT.iterdir()):
        if p.is_file() and p.name not in ['SHA256SUMS.txt','manifest.json']:
            with p.open('rb') as f:digest=hashlib.file_digest(f,'sha256').hexdigest()
            rows.append({'name':p.name,'bytes':p.stat().st_size,'sha256':digest})
    (OUT/'SHA256SUMS.txt').write_text(''.join(row['sha256']+'  '+row['name']+'\n' for row in rows),encoding='utf-8')
    dump(OUT/'manifest.json',{'version':'2.3.2','public_release':False,'files':rows})
    print('CANDIDATE_PACKAGED',json.dumps(rows),flush=True)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('target',choices=['prepare','finish','package']);p.add_argument('--baseline',type=Path,default=ROOT/'build/Release-2.3.1');a=p.parse_args()
    if a.target=='package':package()
    else:globals()[a.target](a.baseline)
