"""Blender 4.5 offline compatibility conversion and baked seated/standing poses.
Run: blender --background --python blender/prepare_modular_drivers.py
Sources remain read-only. Materials and UVs come from each authored asset.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT.parents[1]/'sources/driver_glb'
OUT=ROOT/'assets/models/bigster'

def evaluated_bounds():
    graph=bpy.context.evaluated_depsgraph_get();v=[]
    for o in bpy.context.scene.objects:
        if o.type=='MESH':
            e=o.evaluated_get(graph);m=e.to_mesh()
            v.extend(e.matrix_world@x.co for x in m.vertices);e.to_mesh_clear()
    return Vector(tuple(min(p[i] for p in v) for i in range(3))),Vector(tuple(max(p[i] for p in v) for i in range(3)))

def aim(arm,bone,target):
    p=arm.pose.bones.get(bone)
    if not p:return
    bpy.context.view_layer.update()
    direction=p.tail-p.head
    q=direction.rotation_difference(Vector(target).normalized())
    matrix=p.matrix.copy();matrix=Matrix.Translation(p.head)@q.to_matrix().to_4x4()@Matrix.Translation(-p.head)@matrix
    p.matrix=matrix
    bpy.context.view_layer.update()

for key,file in [('human','Shaven_Leo_driver.glb')]:
    for seated in [True]:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(SRC/file))
        # Blender's glTF armature importer creates this custom bone-display mesh.
        # It is an editor helper, not a source glTF mesh or part of either driver.
        for obj in list(bpy.context.scene.objects):
            if obj.type=='MESH' and not obj.data.materials and obj.name.startswith('Icosphere'):
                bpy.data.objects.remove(obj,do_unlink=True)
        # Blender is Z-up; the helmet source lies along -Y after glTF import.
        root=bpy.data.objects.new('DriverNormalization',None);bpy.context.collection.objects.link(root)
        for o in list(bpy.context.scene.objects):
            if o!=root and o.parent is None:o.parent=root
        # The importer resolves the source skin's axis conversion; both evaluated
        # skeletons are already upright in Blender Z-up.
        root.rotation_euler.z=math.pi
        bpy.context.view_layer.update()
        lo,hi=evaluated_bounds();height=hi.z-lo.z
        root.scale*=1.7/max(height,.01)
        bpy.context.view_layer.update();lo,hi=evaluated_bounds()
        root.location-=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
        bpy.context.view_layer.update()
        if seated:
            arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
            # Targets in armature coordinates. Source driver has a different up axis.
            inv=arm.matrix_world.inverted().to_3x3()
            world_forward=Vector((0,1,0));world_down=Vector((0,0,-1))
            def direction(v):return inv@v
            if key=='human':
                for side,num in [('Left',''),('Right','')]:
                    for b in arm.pose.bones:
                        if b.name.startswith(side+'UpLeg'):aim(arm,b.name,direction(world_forward+world_down*.28))
                        elif b.name.startswith(side+'Leg_'):aim(arm,b.name,direction(world_down+world_forward*.12))
                for side in ['Left','Right']:
                    for b in arm.pose.bones:
                        if b.name.startswith(side+'Arm_'):aim(arm,b.name,direction(world_forward*.7+world_down*.7))
                        elif b.name.startswith(side+'ForeArm_'):aim(arm,b.name,direction(world_forward+Vector((0,0,.1))))
            else:
                for side in ['L','R']:
                    for prefix,target in [('thigh.',world_forward+world_down*.28),('shin.',world_down+world_forward*.12),('upper_arm.',world_forward*.7+world_down*.7),('forearm.',world_forward+Vector((0,0,.1)))]:
                        for b in arm.pose.bones:
                            if b.name.startswith(prefix+side):aim(arm,b.name,direction(target))
        # Bake evaluated geometry to static meshes: runtime poses need no skeleton CPU.
        bpy.context.view_layer.update();graph=bpy.context.evaluated_depsgraph_get()
        copies=[]
        for obj in list(bpy.context.scene.objects):
            if obj.type!='MESH':continue
            mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(graph),preserve_all_data_layers=True,depsgraph=graph)
            clone=bpy.data.objects.new(obj.name+'_baked',mesh);bpy.context.collection.objects.link(clone);clone.matrix_world=obj.matrix_world.copy();copies.append(clone)
        pelvis_anchor=arm.matrix_world @ next(b.head for b in arm.pose.bones if b.name.startswith('Hips_'))
        for obj in list(bpy.context.scene.objects):
            if obj not in copies:bpy.data.objects.remove(obj,do_unlink=True)
        # Seating is anchored at the pelvis, with feet below and helmet above.
        lo,hi=evaluated_bounds()
        anchor=pelvis_anchor if seated else Vector(((lo.x+hi.x)/2,0,lo.z))
        for obj in copies:obj.location-=anchor
        bpy.ops.object.select_all(action='SELECT')
        path=OUT/f'driver_{key}_{"seated" if seated else "standing"}.glb'
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_materials='EXPORT',export_image_format='AUTO')
        print('DRIVER_PREPARED',path.name,flush=True)
