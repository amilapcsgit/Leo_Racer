"""Save reviewable milestone candidates without touching the original installation."""
from pathlib import Path
import hashlib,json,shutil,sys
ROOT=Path(__file__).resolve().parents[1]
QA=ROOT/'build/distinct'
FINAL=ROOT/'build/Distinct-v3-final'
def read(name):return json.loads((QA/name).read_text(encoding='utf-8'))
def digest(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def main(milestone):
    paths=['v3-regression/acceptance.json','features-forward/features.json','pace-forward/pace.json','races-forward/races.json','packaged-acceptance.json']
    if milestone>=2:paths+=['v3-framing/framing.json','v3-visual-forward-final/visual.json','v3-visual-compatibility/visual.json','v3-presentation-forward/presentation.json','v3-presentation-compatibility/presentation.json','packaged-camera-forward/camera-test.json','packaged-camera-compatibility/camera-test.json']
    if milestone==3:paths+=['performance-acceptance.json']
    for name in paths:assert read(name)['status']=='PASS',name
    target=FINAL if milestone==3 else ROOT/f'build/LeoRacer-2.4.1-Milestone-{milestone}'
    if target!=FINAL:shutil.copytree(FINAL,target,dirs_exist_ok=True,ignore=shutil.ignore_patterns('TestProfile','*.pdb'))
    evidence=target/'Evidence';evidence.mkdir(exist_ok=True)
    for name in paths:
        dest=evidence/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(QA/name,dest)
    for name in ['fleet-audit.json','suv-idle.wav','sport-idle.wav','small-idle.wav','bus-idle.wav','electric-idle.wav']:
        path=QA/'v3-regression'/name
        if path.exists():shutil.copy2(path,evidence/name)
    manifest={'version':'2.4.1','ruleset':'distinct_v3','milestone':milestone,'local_private_candidate':True,'vehicles':48,'tracks':3,'acceptance':paths,'binary_sha256':{p.name:digest(p) for p in target.iterdir() if p.is_file() and p.suffix in ['.exe','.pck']}}
    (target/'MILESTONE.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    (target/'MILESTONE_REPORT.md').write_text(f'# Leo Racer 2.4.1 — milestone {milestone}\n\nIntegrated local candidate; all 48 original vehicle packages are preserved.\n\n'+ '\n'.join('- PASS: '+name for name in paths)+'\n\nLaunch Play Test Build.cmd. Its isolated TestProfile keeps existing saves and records separate.\n',encoding='utf-8')
    if milestone<3:shutil.copy2(target/'MILESTONE_REPORT.md',target/'TEST_REPORT.md')
    print(json.dumps({'milestone':milestone,'folder':str(target),'status':'PASS','binary_sha256':manifest['binary_sha256']}))
if __name__=='__main__':main(int(sys.argv[1]))
