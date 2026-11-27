"""Build additive cockpit derivatives; never alter official source packages."""
from pathlib import Path
import json,subprocess,shutil,hashlib
R=Path(__file__).resolve().parents[1]
for key in ['bigster','duster_2024']:
 source=R/'build/refine278'/('cockpit-source-'+key);source.mkdir(parents=True,exist_ok=True)
 original=R/'assets/models/bigster/bigster_232.glb' if key=='bigster' else R.parent.parent/'Duster_2024/package/GameAssets/vehicles/duster_2024/model.glb'
 data=json.loads((R/'build/content-baseline/GameAssets/vehicles'/key/'vehicle.json').read_text(encoding='utf-8'))
 data.update(ultra_cockpit=True,ultra_trunk=key=='bigster',model='model.glb')
 shutil.copy2(original,source/'model.glb');(source/'vehicle.json').write_text(json.dumps(data),encoding='utf-8')
 destination=R/'build/refine278'/('cockpit-compiled-'+key)
 subprocess.run(['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(R/'tools/run_godot.ps1'),'--headless','--script','res://tools/compile_vehicle260.gd','--drive-test','--source='+str(source),'--destination='+str(destination)],cwd=R,check=True)
 target=R/'content/ultra'/('cockpit278-'+key+'.pck');shutil.copy2(destination/'vehicle.pck',target)
 report=json.loads((destination/'compile-report.json').read_text(encoding='utf-8'));metadata=json.loads((destination/'vehicle.json').read_text(encoding='utf-8'));report.update(removed_stalk_triangles=metadata.get('removed_stalk_triangles',0),column_repair_vertices=metadata.get('column_repair_vertices',0));report.update(original_sha256=hashlib.sha256(original.read_bytes()).hexdigest(),derivative_sha256=hashlib.sha256(target.read_bytes()).hexdigest())
 target.with_suffix('.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
