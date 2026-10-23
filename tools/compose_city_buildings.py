"""Assemble audited kit modules; geometry/UVs stay in shared premade GLBs."""
from pathlib import Path
import json,math
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models/colombo_city'
audit=json.loads((OUT/'modules.json').read_text())
modules={m['source_node_index']:m for m in audit['modules']}
folder=OUT/'recipes';folder.mkdir(exist_ok=True)
recipes=[]
styles=[('tea_shop',8,12,1,False,1),('fort_corner',6,20,2,False,1),
        ('coast_cafe',46,14,1,False,1),('bakery',4,22,0,True,1),
        ('shophouse',8,26,2,False,1),('balcony_house',6,14,1,True,1),
        ('market_terrace',8,12,1,False,2),('commercial_corner',6,20,3,False,2),
        ('courtyard_shops',4,26,0,False,2),('fort_apartments',8,12,3,False,2),
        ('lake_residence',46,16,2,False,1),('garden_cafe',46,22,0,True,1)]
for name,ground,upper,floors,pitched,bays in styles:
    components=[];width=6.912*bays;depth=7.424
    def part(module,x,y,z,yaw=0.,scale=None):
        m=modules[module]
        components.append({'module':m['id'],'asset':m['path'],'position':[round(x,4),round(y,4),round(z,4)],
                           'yaw':yaw,'scale_xyz':scale or [6.912/m['width'],1.,1.], 'role':m['role']})
    for bay in range(bays):
        x=(bay-(bays-1)/2)*6.912
        for side in (1,-1):
            z=side*1.856;yaw=0. if side==1 else math.pi
            base=32 if ground==46 else ground
            part(base,x,0,z,yaw)
            if ground==46 and side==1:part(46,x,0,z+1.8,0.,[1.,1.,1.])
            ground_height=modules[base]['height']
            for floor in range(floors):part(upper,x,ground_height+floor*3.2,z,yaw)
            top=ground_height+floors*3.2
            part(34 if pitched else 48,x,top-.06,z,yaw,
                 [6.912/modules[34 if pitched else 48]['width'],1.,1.08 if pitched else 1.])
        # Small authored rooftop dressing, never an AC cube standing in the road.
        if not pitched:part(68,x-1.8,top+.7,-1.,0.,[.65,.65,.65])
    paths=sorted({p['asset'] for p in components});ids={p:str(i+1) for i,p in enumerate(paths)}
    text='[gd_scene load_steps=%d format=3]\n\n'%(len(paths)+1)
    for p in paths:text+='[ext_resource type="PackedScene" path="%s" id="%s"]\n'%(p,ids[p])
    text+='\n[node name="%s" type="Node3D"]\n'%name
    for i,p in enumerate(components):
        text+='\n[node name="Part%d" parent="." instance=ExtResource("%s")]\n'%(i,ids[p['asset']])
        text+='position = Vector3(%s)\n'%(', '.join(map(str,p['position'])))
        text+='rotation = Vector3(0, %s, 0)\n'%p['yaw']
        text+='scale = Vector3(%s)\n'%(', '.join(map(str,p['scale_xyz'])))
    (folder/(name+'.tscn')).write_text(text,encoding='utf-8',newline='\n')
    height=max(p['position'][1]+modules[int(p['module'].split('_')[1])]['height']*p['scale_xyz'][1] for p in components)
    recipes.append({'id':'colombo_'+name,'path':'res://'+(folder/(name+'.tscn')).relative_to(ROOT).as_posix(),
        'width':width,'height':height,'depth':depth+(1.8 if ground==46 else .4),'front_axis':'+Z',
        'floors':floors+1,'pitched':pitched,'components':components,'entrance':True,'complete_roof':True})
data={'format':2,'recipes':recipes,'units':'metres','floor_height':3.2,'seed':23102026}
(OUT/'recipes.json').write_text(json.dumps(data,indent=2)+'\n')
manifest=json.loads((OUT/'manifest.json').read_text())
if 'legacy_buildings' not in manifest:manifest['legacy_buildings']=[b for b in manifest['buildings'] if 'lowrise' in b['id']]
manifest['buildings']=[b for b in manifest['buildings'] if 'tower' in b['id']]+recipes
manifest['modules']='res://assets/models/colombo_city/modules.json'
manifest['recipes']='res://assets/models/colombo_city/recipes.json'
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('COMPLETE_BUILDING_RECIPES',len(recipes))
