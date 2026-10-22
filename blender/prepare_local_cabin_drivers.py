"""Bake cabin-only variants. Original open-kart models remain byte-identical.
Blender Z-up. Export normalizes to Godot +Y up, forward -Z, pelvis origin.
Bigster scaling belongs solely to the vehicle seating transform.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models/cabin';OUT.mkdir(exist_ok=True)
# Reuse the authored Mario rig and the existing proven cabin posing pipeline.
source=(ROOT/'blender/prepare_dacia_driver.py').read_text(encoding='utf-8')
source=source.replace("OUT=ROOT/'assets/models/bigster'","OUT=ROOT/'assets/models/cabin'")
source=source.replace("[('human','Shaven_Leo_driver.glb')]","[('mario','mario_driver.glb')]")
source=source.replace("next(b.head for b in arm.pose.bones if b.name.startswith('Hips_'))","next(b.head for b in arm.pose.bones if b.name.startswith('Base_'))")
source=source.replace('for obj in copies:obj.location-=anchor','for obj in copies:\n            obj.location-=anchor\n            obj.location*=.79\n            obj.scale*=.79')
exec(compile(source,str(ROOT/'blender/prepare_dacia_driver.py'),'exec'))
def godot(v):return Vector((v.x,v.z,-v.y))
def blender(v):return Vector((v.x,-v.z,v.y))
report={}
for key in ['hedgehog','lion','elephant','parrot']:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(ROOT/f'assets/models/driver_{key}.glb'))
 scale=.40 if key=='parrot' else .44
 pelvis=Vector((0,.85,.19));hand_targets=[]
 for obj in list(bpy.context.scene.objects):
  if obj.type!='MESH':continue
  # Bake importer transform and walk original disconnected sculpted components.
  points=[godot(obj.matrix_world@v.co) for v in obj.data.vertices]
  adjacency=[[] for _ in points]
  for edge in obj.data.edges:
   a,b=edge.vertices;adjacency[a].append(b);adjacency[b].append(a)
  seen=set()
  for start in range(len(points)):
   if start in seen:continue
   stack=[start];seen.add(start);indices=[]
   while stack:
    i=stack.pop();indices.append(i)
    for j in adjacency[i]:
     if j not in seen:seen.add(j);stack.append(j)
   lo=Vector(tuple(min(points[i][a] for i in indices) for a in range(3)))
   hi=Vector(tuple(max(points[i][a] for i in indices) for a in range(3)))
   center=(lo+hi)*.5;side=-1 if center.x<0 else 1
   glove=Vector((side*.4,1.07,-.48));shoulder=Vector((side*.36,1.4,.05))
   desired_hand=Vector((side*.15,.28,-.46))
   original_a=(shoulder-pelvis)*scale;original_b=(glove-pelvis)*scale
   if (center-glove).length<.035:
    shift=desired_hand-original_b
    for i in indices:points[i]=(points[i]-pelvis)*scale+shift
    hand_targets.append(list(desired_hand))
   elif (center-(glove+shoulder)*.5).length<.04:
    old_axis=original_b-original_a;new_axis=desired_hand-original_a
    rotation=old_axis.rotation_difference(new_axis)
    for i in indices:
     offset=(points[i]-pelvis)*scale-original_a
     along=old_axis*(offset.dot(old_axis)/old_axis.length_squared)
     points[i]=original_a+rotation@(offset-along)+new_axis*(offset.dot(old_axis)/old_axis.length_squared)
   else:
    for i in indices:points[i]=(points[i]-pelvis)*scale
  if key=='elephant':
   for p in points:p.x*=.83
  for i,p in enumerate(points):obj.data.vertices[i].co=blender(p)
  obj.matrix_world.identity();obj.data.update()
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.export_scene.gltf(filepath=str(OUT/f'driver_{key}_cabin.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_materials='EXPORT')
 report[key]={'pelvis':[0,0,0],'hands':hand_targets,'scale':scale,'source':f'assets/models/driver_{key}.glb'}
(ROOT/'docs/qa-local2player/cabin-derivation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')

