"""Offline Blender conversion of user-authorized Kandy scenery; sources remain untouched."""
import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path.cwd();OUT=ROOT/'build/kandy/supplied-models/runtime';OUT.mkdir(parents=True,exist_ok=True)
SOURCE=Path('C:/Users/amilapcs/Downloads');reports=[]
def convert(key,source,height,select=None):
 path=SOURCE/source
 bpy.ops.wm.read_factory_settings(use_empty=True)
 if path.suffix=='.blend':bpy.ops.wm.open_mainfile(filepath=str(path))
 elif path.suffix=='.stl':bpy.ops.wm.stl_import(filepath=str(path))
 else:bpy.ops.import_scene.gltf(filepath=str(path))
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and (select is None or select(o))]
 # Evaluate while source curves/helpers still exist (the stupa fence uses a Curve modifier).
 graph=bpy.context.evaluated_depsgraph_get()
 baked={o:bpy.data.meshes.new_from_object(o.evaluated_get(graph),depsgraph=graph) for o in meshes}
 for o,data in baked.items():o.modifiers.clear();o.data=data
 for o in list(bpy.context.scene.objects):
  if o not in meshes:bpy.data.objects.remove(o,do_unlink=True)
 bpy.ops.object.select_all(action='SELECT')
 bpy.context.view_layer.objects.active=meshes[0]
 for o in meshes:
  bpy.context.view_layer.objects.active=o
  if len(o.data.polygons)>20000:
   mod=o.modifiers.new('Runtime silhouette preservation','DECIMATE');mod.ratio=20000/len(o.data.polygons)
   bpy.ops.object.modifier_apply(modifier=mod.name)
 vs=[o.matrix_world@Vector(v) for o in meshes for v in o.bound_box]
 low=Vector([min(v[i] for v in vs) for i in range(3)]);high=Vector([max(v[i] for v in vs) for i in range(3)])
 scale=height/(high.z-low.z);offset=Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
 for o in meshes:
  matrix=o.matrix_world.copy()
  for v in o.data.vertices:v.co=(matrix@v.co-offset)*scale
  o.parent=None;o.matrix_world=Matrix.Identity(4)
  if key=='tooth_temple':
   for name,color in [('Ivory masonry',(.72,.67,.51,1)),('Clay tile roofs',(.28,.065,.025,1))]:
    m=bpy.data.materials.new(name);m.diffuse_color=color;m.use_nodes=True;m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=color;m.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.86;o.data.materials.append(m)
   for f in o.data.polygons:f.material_index=1 if .15<f.normal.z<.95 and f.center.z>height*.12 else 0
  if not o.data.materials:
   m=bpy.data.materials.new('Warm ivory');m.diffuse_color=(.85,.82,.70,1);o.data.materials.append(m)
 for image in bpy.data.images:
  if image.size[0] and max(image.size)>2048:image.scale(int(image.size[0]*2048/max(image.size)),int(image.size[1]*2048/max(image.size)))
 bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join()
 model=bpy.context.object;model.name=key
 # Joining preserves the active object's origin. Bake and recenter once more so
 # the runtime root is guaranteed centered and grounded, regardless of source origins.
 vertices=[model.matrix_world@v.co for v in model.data.vertices]
 mn=Vector([min(v[i] for v in vertices) for i in range(3)]);mx=Vector([max(v[i] for v in vertices) for i in range(3)])
 origin=Vector(((mn.x+mx.x)/2,(mn.y+mx.y)/2,mn.z));factor=height/(mx.z-mn.z)
 for vertex,world in zip(model.data.vertices,vertices):vertex.co=(world-origin)*factor
 model.parent=None;model.matrix_world=Matrix.Identity(4)
 model.data.update()
 target=OUT/(key+'.glb')
 bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
 reports.append(dict(id=key,source=source,source_sha256=hashlib.file_digest((SOURCE/source).open('rb'),'sha256').hexdigest(),triangles=sum(len(p.vertices)-2 for p in model.data.polygons),height_m=height,model=target.name,bytes=target.stat().st_size,permission='User explicitly authorized supplied model use on 2026-10-25'))
convert('mahaweli','Mahaweli+Seya.blend',60)
convert('tooth_temple','Temple-of-Tooth Relic-Sri-Lanka-MiniWorld3D.stl',14)
def tree(o):
 if o.name.startswith('Plane.002_'):return False
 corners=[o.matrix_world@Vector(v) for v in o.bound_box];c=sum(corners,Vector())/8
 return (c.x+10.565)**2+c.y*c.y<1.15**2
convert('forest','a_forest_3_with_a_road_at_night_for_game.glb',13,tree)
(OUT/'provenance.json').write_text(json.dumps({'models':reports,'fbx_exception':'Inspected 609 meshes/129524 triangles. All referenced original texture files are missing; not installed pending material reconstruction. No source edited.','mahaweli_reference':'https://www.cgtrader.com/free-3d-models/architectural/other/mahaweli-stupa-3d-model','mahaweli_creator':'sachinthabasna','placement':'Artistic Kandy-inspired landmark, not geographically accurate relocation claim.'},indent=2),encoding='utf-8')
