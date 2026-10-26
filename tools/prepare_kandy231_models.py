"""Read supplied models; write reviewed runtime derivatives only (Blender 4.5)."""
import bpy, sys, json, hashlib, zipfile, math
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'build/kandy231'
OUT=ROOT/'build/kandy/supplied-models/runtime'
OUT.mkdir(parents=True,exist_ok=True)
SOURCE=Path.home()/'Downloads'
sys.path.insert(0,str(WORK/'dependencies/openskp/vendor'))
sys.path.append(str(WORK/'dependencies/python311'))
reports=[]

def material(name,color):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=color;p.inputs['Roughness'].default_value=.85
    m.diffuse_color=color
    return m

def skp(path):
    from openskp import SkpFile
    scene=SkpFile.open(str(path)).build_scene()
    mats=[]
    for index,data in enumerate(scene.gltf_materials):
        pbr=data['pbrMetallicRoughness'];m=material('Source_%03d'%index,pbr['baseColorFactor'])
        texture=pbr.get('baseColorTexture')
        if texture:
            tex=scene.textures[texture['index']]
            file=WORK/('embedded_%03d.png'%index);file.write_bytes(tex.data)
            image=bpy.data.images.load(str(file));image.pack()
            node=m.node_tree.nodes.new('ShaderNodeTexImage');node.image=image
            m.node_tree.links.new(node.outputs['Color'],m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
        mats.append(m)
    for i,prim in enumerate(scene.glb_primitives):
        xyz=list(prim.positions);indices=list(prim.indices)
        verts=[(xyz[j],-xyz[j+2],xyz[j+1]) for j in range(0,len(xyz),3)]
        faces=[indices[j:j+3] for j in range(0,len(indices),3)]
        mesh=bpy.data.meshes.new('SketchUp_%d'%i);mesh.from_pydata(verts,[],faces);mesh.update()
        mesh.materials.append(mats[prim.material_index])
        uv=mesh.uv_layers.new(name='UVMap')
        for loop in mesh.loops:
            v=loop.vertex_index;uv.data[loop.index].uv=(prim.uvs[v*2],prim.uvs[v*2+1])
        o=bpy.data.objects.new('SketchUp_%d'%i,mesh);bpy.context.collection.objects.link(o)

def prepare(key,source,height):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path=SOURCE/source
    if path.suffix=='.skp':skp(path)
    elif path.suffix=='.zip':
        dest=WORK/'inputs'/key;dest.mkdir(parents=True,exist_ok=True)
        with zipfile.ZipFile(path) as z:z.extractall(dest)
        bpy.ops.wm.collada_import(filepath=str(dest/'model.dae'))
    else:bpy.ops.wm.open_mainfile(filepath=str(path))
    if key=='mahaweli':
        # The source's lower colonnade is deliberately removed from this derivative.
        for o in list(bpy.context.scene.objects):
            if o.type!='MESH':continue
            bounds=[o.matrix_world@Vector(v) for v in o.bound_box]
            print('STUPA_PART',o.name,tuple(min(v[i] for v in bounds) for i in range(3)),tuple(max(v[i] for v in bounds) for i in range(3)),flush=True)
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and len(o.data.polygons)]
    assert meshes,key+' contains no faces'
    graph=bpy.context.evaluated_depsgraph_get()
    evaluated={o:bpy.data.meshes.new_from_object(o.evaluated_get(graph),depsgraph=graph) for o in meshes}
    world_matrices={o:o.matrix_world.copy() for o in meshes}
    for o,data in evaluated.items():o.modifiers.clear();o.data=data
    for o in list(bpy.context.scene.objects):
        if o not in meshes:bpy.data.objects.remove(o,do_unlink=True)
    if key=='mahaweli':
        # Select white architectural body, not the narrow cylindrical dark supports.
        for o in meshes[:]:
            bounds=[o.matrix_world@Vector(v) for v in o.bound_box]
            size=Vector([max(v[i] for v in bounds)-min(v[i] for v in bounds) for i in range(3)])
            if o.name=='Cylinder':
                meshes.remove(o);bpy.data.objects.remove(o,do_unlink=True)
    vertices=[world_matrices[o]@v.co for o in meshes for v in o.data.vertices]
    low=Vector([min(v[i] for v in vertices) for i in range(3)])
    high=Vector([max(v[i] for v in vertices) for i in range(3)])
    factor=height/(high.z-low.z);origin=Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
    for o in meshes:
        matrix=world_matrices[o]
        for v in o.data.vertices:v.co=(matrix@v.co-origin)*factor
        o.parent=None;o.matrix_world=Matrix.Identity(4)
        if key=='mahaweli':
            o.data.materials.clear();o.data.materials.append(material('White limewashed masonry',(.83,.82,.76,1)))
        if not o.data.materials:o.data.materials.append(material('Limewashed masonry',(.75,.73,.64,1)))
        # Preserve architectural triangulation rather than aggressively decimating roofs.
        bpy.context.view_layer.objects.active=o;o.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
        o.select_set(False)
    for image in bpy.data.images:
        if max(image.size)>2048:
            ratio=2048/max(image.size);image.scale(max(1,int(image.size[0]*ratio)),max(1,int(image.size[1]*ratio)))
    for o in meshes:o.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join()
    model=bpy.context.object;model.name=key
    if key in ['jungle_temple','ceypetco']:
        import bmesh
        bm=bmesh.new();bm.from_mesh(model.data)
        ground_limit=height*(.20 if key=='jungle_temple' else .06)
        floor=[f for f in bm.faces if abs(f.normal.z)>.98 and f.calc_center_median().z<ground_limit and f.calc_area()>30.]
        if key=='jungle_temple':floor=list(set(floor+[f for f in bm.faces if max(v.co.z for v in f.verts)<1.8]))
        if key=='ceypetco':floor=list(set(floor+[f for f in bm.faces if max(v.co.z for v in f.verts)<2.51]))
        bmesh.ops.delete(bm,geom=floor,context='FACES')
        bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
        bm.to_mesh(model.data);bm.free();model.data.update()
        base=2.52 if key=='ceypetco' else min(v.co.z for v in model.data.vertices)
        for vertex in model.data.vertices:vertex.co.z-=base
    # UV2 is retained for Godot's landmark lightmaps.
    if len(model.data.uv_layers)<2:
        model.data.uv_layers.new(name='Lightmap')
    model.data.uv_layers.active_index=1
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT')
    model.data.uv_layers.active_index=0
    target=OUT/(key+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK/(key+'.blend')))
    actual_height=max(v.co.z for v in model.data.vertices)-min(v.co.z for v in model.data.vertices)
    report={'id':key,'source':source,'source_sha256':hashlib.file_digest(path.open('rb'),'sha256').hexdigest(),'triangles':sum(len(p.vertices)-2 for p in model.data.polygons),'height_m':round(actual_height,4),'bytes':target.stat().st_size,'model':target.name}
    reports.append(report);print('MODEL_READY',json.dumps(report),flush=True)

for key,source,height in [('tooth_temple','kandy toothtemple.skp',14.),('jungle_temple','jungle temple.skp',12.),('buddha','Standing+Buddha+statue+Srilanka.zip',18.),('ceypetco','CEYPETCO.zip',7.),('mahaweli','Mahaweli+Seya.blend',60.)]:
    requested=next((arg.split('=',1)[1] for arg in sys.argv if arg.startswith('--only=')),None)
    if requested and requested!=key:continue
    prepare(key,source,height)
if requested:
    old=json.loads((WORK/'models.json').read_text())
    reports=[r for r in old['models'] if r['id']!=requested]+reports
(WORK/'models.json').write_text(json.dumps({'models':reports,'importer':'OpenSKP v0.2.4','source_files_unchanged':True},indent=2),encoding='utf-8')
