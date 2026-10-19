"""Reproducible bootstrap catalog. Future entries use the editor import dock."""
import json
from pathlib import Path
import numpy as np
from modular_glb import GLB,points
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/catalog';OUT.mkdir(parents=True,exist_ok=True)
def vec(a):return 'Vector3('+', '.join(str(round(float(x),7)) for x in a)+')'
def string(s):return json.dumps(s,ensure_ascii=False)
def transform(pos=(0,0,0),scale=(1,1,1)):
 return 'Transform3D(%s)'%', '.join(map(str,[scale[0],0,0,0,scale[1],0,0,0,scale[2],*pos]))
drivers=[('hedgehog','Sonic','Blue blur. Big grin. Born for the coast.'),('lion','Leo','A little lion with a roaring racing heart.'),('elephant','Ellie','Small kart. Giant island energy.'),('parrot','Rio','Tropical colour. Fearless corners.'),('human','Shaven Leo','Helmet on. Heart racing. Full throttle.'),('mario','Mario','A new face at the island starting line.')]
for key,name,tag in drivers:
 new=key in ['human','mario'];base=f'res://assets/models/modular/driver_{key}_' if new else f'res://assets/models/driver_{key}.glb'
 seated=base+'seated.glb' if new else base;standing=base+'standing.glb' if new else base
 text='[gd_resource type="Resource" script_class="DriverDefinition" load_steps=5 format=3]\n\n'
 text+='[ext_resource type="Script" path="res://scripts/catalog/driver_definition.gd" id="1"]\n'
 text+=f'[ext_resource type="PackedScene" path="{seated}" id="2"]\n[ext_resource type="PackedScene" path="{standing}" id="3"]\n'
 if key=='human':text+='[ext_resource type="Texture2D" path="res://assets/models/modular/helmet_driver.png" id="4"]\n'
 text+='\n[resource]\nscript = ExtResource("1")\n'+f'id = &"{key}"\ndisplay_name = {string(name)}\ntagline = {string(tag)}\nseated_model = ExtResource("2")\nstanding_model = ExtResource("3")\n'
 text+='setup_complete = true\n'
 if new:text+='orientation = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.0, 0.2)\n'
 if key=='human':text+='material_name = "Wolf3D_Headwear"\nmaterial_albedo = ExtResource("4")\n'
 (OUT/f'driver_{key}.tres').write_text(text,encoding='utf-8')
legacy=[('blue','Blue Bolt',4.5,3.9,4.1,None),('coral','Sunset GT',4.8,3.6,3.8,None),('aqua','Palm Dash',4.,4.8,4.5,None),('pink','Lotus Pop',4.2,4.4,4.8,None),('formula_blue','Formula Blue',4.8,4.2,4.2,38),('formula_red','Formula Red',5.,3.8,4.,39),('roadster_gold','Lion GT',4.6,4.6,4.4,36),('race_tuk','Racing Tuk-Tuk',3.8,5.,5.,32.5),('race_bus','Party Bus',3.6,3.7,3.6,32)]
specs=json.loads((ROOT/'assets/models/astra/vehicle-specs.json').read_text());prepared=json.loads((ROOT/'assets/models/modular/prepared-specs.json').read_text());entries=[]
for i,(key,name,speed,grip,acc,top) in enumerate(legacy):
 path=f'assets/models/{"astra/" if i>=4 else ""}kart_{key}.glb';g=GLB(ROOT/path);ws=g.worlds();wheels=[]
 for j,n in enumerate(g.doc['nodes']):
  if n.get('name','').startswith('wheel-'):
   wheels.append({'name':n['name'],'pivot':ws[j][:3,3].tolist(),'radius':.49,'steering':'front' in n['name'],'axis':[1,0,0]})
 entries.append(dict(id=key,name=name,path=path,wheels=wheels,top=top or 29+speed*.9,acceleration=13+acc*1.2,handling=.8+grip*.05,spec=specs.get(key,{}),legacy=True))
for p in prepared:entries.append(dict(id=p['id'],name=p['name'],path=f"assets/models/modular/{p['id']}.glb",wheels=p['wheels'],top=33,acceleration=18,handling=1,spec={},bounds=p['bounds'],legacy=False))
for e in entries:
 key=e['id'];s=e['spec'];wheels=e['wheels'];legacy=e['legacy']
 text='[gd_resource type="Resource" script_class="VehicleDefinition" format=3]\n\n[ext_resource type="Script" path="res://scripts/catalog/vehicle_definition.gd" id="1"]\n[ext_resource type="Script" path="res://scripts/catalog/wheel_binding.gd" id="2"]\n'
 text+=f'[ext_resource type="PackedScene" path="res://{e["path"]}" id="3"]\n'
 for i,w in enumerate(wheels):
  text+=f'\n[sub_resource type="Resource" id="w{i}"]\nscript = ExtResource("2")\nrotating_groups = Array[NodePath]([NodePath({string(w["name"])})])\n'
  if not legacy and any(n.get('name')==w['name']+'_caliper' for n in GLB(ROOT/e['path']).doc['nodes']):text+=f'stationary_groups = Array[NodePath]([NodePath("{w["name"]}_caliper")])\n'
  text+=f'steering = {str(w["steering"]).lower()}\npivot = {vec(w["pivot"])}\nradius = {w["radius"]}\naxle = Vector3(1, 0, 0)\n'
 text+='\n[resource]\nscript = ExtResource("1")\n'+f'id = &"{key}"\ndisplay_name = {string(e["name"])}\nmodel = ExtResource("3")\nwheels = Array[ExtResource("2")](['+', '.join(f'SubResource("w{i}")' for i in range(len(wheels)))+'])\n'
 size=s.get('collision_size',[min(2.2,e.get('bounds',[2.15])[0]),min(2.5,e.get('bounds',[0,1.4])[1]),min(4.2,e.get('bounds',[0,0,3.5])[2])]);pos=s.get('collision_position',[0,size[1]*.5+.08,0])
 text+=f'collision_size = {vec(size)}\ncollision_position = {vec(pos)}\nmax_speed = {e["top"]}\nacceleration = {e["acceleration"]}\nhandling = {e["handling"]}\n'
 text+=f'seat = {transform(s.get("driver_position",[0,0,0]),s.get("driver_scale",[1,1,1]))}\ndriver_policy = {0 if legacy else 1}\npreserve_materials = {str(not legacy).lower()}\nsetup_complete = true\n'
 if key=='race_bus':text+='camera_height = 0.45\n'
 if key in ['race_tuk','colombo_tuk']:text+='camera_height = 0.2\n'
 if not legacy:
  h=e['bounds'][1];l=e['bounds'][2];text+=f'preview_target = Vector3(0, {h*.5}, 0)\npreview_distance = {max(7.6,l*1.65)}\n'
  text+='normalization = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.08, 0)\n'
  text+='exhausts = PackedVector3Array(-0.5, 0.5, '+str(l*.45)+', 0.5, 0.5, '+str(l*.45)+')\n'
 if key=='hover':text+='hovering = true\n'
 (OUT/f'vehicle_{key}.tres').write_text(text,encoding='utf-8')
text='[gd_resource type="Resource" script_class="GarageCatalog" format=3]\n[ext_resource type="Script" path="res://scripts/catalog/garage_catalog.gd" id="1"]\n[ext_resource type="Script" path="res://scripts/catalog/vehicle_definition.gd" id="v"]\n[ext_resource type="Script" path="res://scripts/catalog/driver_definition.gd" id="d"]\n'
for e in entries:text+=f'[ext_resource type="Resource" path="res://assets/catalog/vehicle_{e["id"]}.tres" id="v_{e["id"]}"]\n'
for key,_,_ in drivers:text+=f'[ext_resource type="Resource" path="res://assets/catalog/driver_{key}.tres" id="d_{key}"]\n'
text+='\n[resource]\nscript = ExtResource("1")\nvehicles = Array[ExtResource("v")](['+', '.join(f'ExtResource("v_{e["id"]}")' for e in entries)+'])\ndrivers = Array[ExtResource("d")](['+', '.join(f'ExtResource("d_{key}")' for key,_,_ in drivers)+'])\n'
(OUT/'catalog.tres').write_text(text,encoding='utf-8')
print('Catalog:',len(entries),'vehicles ×',len(drivers),'drivers')
