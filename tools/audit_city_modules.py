"""Inventory every kit component, retaining short caps and decorative props."""
from pathlib import Path
import hashlib,json
import numpy as np
import prepare_city_buildings as kit
from modular_glb import GLB,points

root=kit.ROOT
g=GLB(kit.INPUT/'city_game_ready_free.glb')
kit.OUT=root/'assets/models/colombo_city/modules'
kit.OUT.mkdir(parents=True,exist_ok=True)
kit.TEXTURES=kit.OUT/'textures';kit.TEXTURES.mkdir(exist_ok=True)
kit.manifest={'modules':[]}
for i,node in enumerate(g.doc['nodes']):
    if 'mesh' not in node:continue
    entry=kit.export(g,i,1.6,f'module_{i:02d}','modules')
    role = ('storefront' if i in (4,6,8) else 'cafe_facade' if i==46 else
            'roof_cap' if i in (28,30,48,50) else 'pitched_roof' if i==34 else
            'upper_floor' if i in (10,12,14,16,18,20,22,24,26,32,36) else 'prop')
    entry.update(source_node_index=i,metres_per_source_unit=1.6,front_axis='+Z',role=role,
                 compatible_roles=['upper_floor','roof_cap','pitched_roof'] if role in ('storefront','upper_floor') else [])
    entry['sockets']={'base':[0,0,0],'top':[0,round(entry['height'],4),0]}
report={'format':2,'source_sha256':hashlib.sha256(g.path.read_bytes()).hexdigest(),
        'source':g.doc['asset'].get('extras',{}),'modules':kit.manifest['modules']}
(root/'assets/models/colombo_city/modules.json').write_text(json.dumps(report,indent=2)+'\n')
reference=root/'source_assets/terrain-reference'
pin={'repository':'https://github.com/bsubard/Godot-3D-Infinite-Procedural-Terrain-With-Trees-and-Grass',
     'commit':'71ff8c816839a8e45c1900c37d1671286371ed89','license':'MIT','upstream_godot':'4.4',
     'files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(reference.iterdir()) if p.is_file()}}
(root/'source_assets/terrain-reference/pin.json').write_text(json.dumps(pin,indent=2)+'\n')
print('AUDITED_SOURCE_COMPONENTS',len(report['modules']))
