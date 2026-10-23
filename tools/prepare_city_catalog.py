"""Derive lazy catalog metadata without touching original vehicle resources."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
target=ROOT/'assets/catalog/runtime';target.mkdir(exist_ok=True)
for path in (ROOT/'assets/catalog').glob('*.tres'):
    if path.name=='catalog.tres':continue
    text=path.read_text()
    models=dict(re.findall(r'\[ext_resource type="PackedScene" path="([^"]+)" id="([^"]+)"\]',text))
    for model,key in models.items():
        text=re.sub(r'^\[ext_resource type="PackedScene"[^\n]+id="'+re.escape(key)+r'"\]\n','',text,flags=re.M)
        text=re.sub(r'^(\w+) = ExtResource\("'+re.escape(key)+r'"\)$',lambda m:m[1]+'_path = "'+model+'"',text,flags=re.M)
    (target/path.name).write_text(text)
text=(ROOT/'assets/catalog/catalog.tres').read_text()
text=text.replace('res://assets/catalog/vehicle_','res://assets/catalog/runtime/vehicle_').replace('res://assets/catalog/driver_','res://assets/catalog/runtime/driver_')
(target/'catalog.tres').write_text(text)
print('LAZY_CATALOG',len(list(target.glob('*.tres'))),'metadata resources')
