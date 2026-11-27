from pathlib import Path
import json,os
import verify_distinct as verify
import release_260 as release
R=release.ROOT;Q=R/'build/qa260';BASE=release.BASE
verify.QA=Q/'export';os.environ['LEO_ASSET_ROOT']=str(BASE/'GameAssets')
report=json.loads((Q/'export-smoke.json').read_text(encoding='utf-8'));assert report['status']=='PASS'
previous=report['core_sha256']
for label,args in [('final-content',['--verify-content']),('final-vehicles',['--validate-vehicles'])]:
 ok=verify.run(label,BASE,args=args,vehicles=BASE/'GameAssets/vehicles',timeout=400)
 report['cases'].append({'case':label,'pass':ok});assert ok,label
report.update(core_sha256=release.sha(BASE/'LeoRacer.pck'),previous_core_sha256=previous,metadata_changes=['Duster 2024 cabin-fit scales','Nero Nacre label'],status='PASS')
release.dump(Q/'export-smoke.json',report)
print('FINAL_METADATA260_PASS',flush=True)
