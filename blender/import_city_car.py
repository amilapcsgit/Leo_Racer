import bpy, os, math
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE=os.path.join(ROOT,'source_assets','rgsdev','Taxi.fbx')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=SOURCE)
objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
corners=[o.matrix_world@Vector(v) for o in objects for v in o.bound_box]
mins=Vector(tuple(min(v[i] for v in corners) for i in range(3)));maxs=Vector(tuple(max(v[i] for v in corners) for i in range(3)))
longest=max(maxs.x-mins.x,maxs.y-mins.y)
scale=4.2/longest
for o in objects:
    # FBX centimetres/metres are normalized after world transform application.
    o.select_set(True)
bpy.context.view_layer.objects.active=objects[0]
bpy.ops.object.join();o=bpy.context.object
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
for v in o.data.vertices:
    v.co=(v.co-Vector(((mins.x+maxs.x)/2,(mins.y+maxs.y)/2,mins.z)))*scale
o.location=(0,0,0);o.name='Colombo_Parked_Taxi_RGSdev'
for m in bpy.data.materials:
    m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    if p:p.inputs['Roughness'].default_value=.45
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'blender','city_vehicle.blend'))
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'assets','models','city_vehicle.glb'),export_format='GLB',export_apply=True,export_animations=False)
print('ITCH_TAXI_CONVERTED',scale)
