"""Reproduce the hatch-capable derivative from preserved checkpoint geometry."""
import json, shutil, subprocess
from pathlib import Path
from stage_ultra_content import ROOT,sha
source=ROOT/'build/ultra-bigster-source';source.mkdir(exist_ok=True)
model=ROOT/'assets/models/bigster/bigster_232.glb'
assert sha(model)=='c38710ec2d9ba01a83aec0957bc0bab635aa1660e957bf6738cfbe91c20f8d62'
shutil.copy2(model,source/'model.glb')
data=json.loads((ROOT/'build/content-baseline/GameAssets/vehicles/bigster/vehicle.json').read_text())
data['ultra_trunk']=True
(source/'vehicle.json').write_text(json.dumps(data))
destination=ROOT/'build/ultra-bigster-compiled'
subprocess.run(['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(ROOT/'tools/run_godot.ps1'),'--headless','--script','res://tools/compile_vehicle260.gd','--drive-test','--source='+str(source),'--destination='+str(destination)],cwd=ROOT,check=True)
target=ROOT/'content/ultra';target.mkdir(exist_ok=True)
shutil.copy2(destination/'vehicle.pck',target/'bigster-trunk.pck')
report=json.loads((destination/'compile-report.json').read_text())
report.update(source_model_sha256=sha(model),source_unchanged=True,moving_parts=['dust25_tailgate_a','dust25_tailgate_carp','Bigster_Tailgate_Badge','Bigster_Tailgate_Dacia_OEM_Badge','Bigster_Tailgate_Patterned_Band','dust25_tailgate_chmsl','dust25_tailgateglass','Bigster_Rear_Plate','Bigster_Rear_Plate_Text'])
(target/'bigster-trunk.json').write_text(json.dumps(report,indent=2)+'\n')
