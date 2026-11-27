from pathlib import Path
import hashlib,json,subprocess
R=Path(__file__).resolve().parents[1];W=R.parent.parent
def sha(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
mod=Path('C:/Users/amilapcs/Downloads/Leo Racer/beamngmods/stiv_duster_v2')
expected=json.loads((W/'Duster_My_2014/source_hashes.json').read_text(encoding='utf-8'))
errors=[]
for name,value in expected.items():
 if sha(mod/name)!=value:errors.append(name)
report=json.loads((W/'Duster_2024/conversion_report.json').read_text(encoding='utf-8'))
original=W/'Bigster/duster_MANUALFIX.blend'
if sha(original)!=report['source_sha256']:errors.append(str(original))
components={}
for name in ['scripts/contact_solver.gd','scripts/cosmetic_damage.gd','scripts/local/race_camera.gd']:
 old=subprocess.check_output(['git','show','3d37854:'+name],cwd=R)
 same=hashlib.sha256(old.replace(b'\r\n',b'\n')).hexdigest()==hashlib.sha256((R/name).read_bytes().replace(b'\r\n',b'\n')).hexdigest()
 components[name]={'unchanged':same,'sha256':sha(R/name)}
 if not same:errors.append(name)
masters={str(p.relative_to(W)):sha(p) for p in [original,W/'Duster_My_2014/Duster_My_2014.blend',W/'Duster_2024/Duster_2024_runtime.blend']}
result={'status':'PASS' if not errors else 'FAIL','source_mod_files':len(expected),'errors':errors,'original_duster_2024_unchanged':str(original) not in errors,'unchanged_25_components':components,'masters':masters}
(R/'build/qa260/source-integrity.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
assert not errors,errors
print('SOURCE_INTEGRITY_PASS',len(expected),flush=True)
