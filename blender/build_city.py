"""Normalize Kenney City Kit Commercial 2.1 for the Lotus Coast streetscape.

Run from the project workspace with Blender 4.5 --background --factory-startup
--python blender/build_city.py. CC0 source is included in source_assets/.
Palette UV shading is baked to corner colors. Walls become a tintable surface;
windows keep their own PBR surface. All geometry is shared by city.gd batches.
"""
import bpy, os, json, zipfile
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE_ROOT = os.path.join(ROOT, 'source_assets', 'kenney-city')
if not os.path.isdir(SOURCE_ROOT):
    with zipfile.ZipFile(os.path.join(ROOT, 'source_assets', 'kenney_city-kit-commercial_2.1.zip')) as archive:
        archive.extractall(SOURCE_ROOT)
SRC = os.path.join(SOURCE_ROOT, 'Models', 'GLB format')
OUT = os.path.join(ROOT, 'assets', 'models', 'city')
os.makedirs(OUT, exist_ok=True)

def material(name, roughness=.75, metallic=0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Metallic'].default_value = metallic
    vc = m.node_tree.nodes.new('ShaderNodeVertexColor'); vc.layer_name = 'CityColor'
    m.node_tree.links.new(vc.outputs['Color'], p.inputs['Base Color'])
    return m

def linear(c): return c / 12.92 if c <= .04045 else ((c+.055)/1.055)**2.4

manifest = {}
names = ['building-'+chr(i) for i in range(ord('a'),ord('n')+1)]
names += ['building-skyscraper-'+chr(i) for i in range(ord('a'),ord('e')+1)]
names += ['detail-awning-wide','detail-parasol-a','detail-parasol-b']
for name in names:
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    for m in list(bpy.data.materials): bpy.data.materials.remove(m)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC,name+'.glb'))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    verts = [o.matrix_world @ Vector(p) for o in meshes for p in o.bound_box]
    minimum = [min(p[i] for p in verts) for i in range(3)]
    maximum = [max(p[i] for p in verts) for i in range(3)]
    manifest[name] = {'width':round((maximum[0]-minimum[0])*10,3), 'height':round((maximum[2]-minimum[2])*10,3), 'depth':round((maximum[1]-minimum[1])*10,3), 'triangles':sum(len(o.data.polygons) for o in meshes)}
    detail = material('City_Detail',.68)
    wall = material('City_Wall',.82)
    glass = material('City_Glass',.22,.28)
    for o in meshes:
        mesh = o.data
        old = mesh.materials[0]
        image = next(n.image for n in old.node_tree.nodes if n.type == 'TEX_IMAGE')
        mapping = next((n for n in old.node_tree.nodes if n.type == 'MAPPING'),None)
        offset = mapping.inputs['Location'].default_value[:] if mapping else (0,0,0)
        scale = mapping.inputs['Scale'].default_value[:] if mapping else (1,1,1)
        px = list(image.pixels); w,h = image.size
        colors = mesh.color_attributes.new(name='CityColor',type='FLOAT_COLOR',domain='CORNER')
        mesh.materials.clear()
        for m in [detail,wall,glass]: mesh.materials.append(m)
        def sample(li):
            uv = mesh.uv_layers.active.data[li].uv
            u = min(w-1,max(0,int((uv.x*scale[0]+offset[0])*w)))
            v = min(h-1,max(0,int((uv.y*scale[1]+offset[1])*h)))
            return px[4*(v*w+u):4*(v*w+u)+3]
        for face in mesh.polygons:
            samples = [sample(li) for li in face.loop_indices]
            r,g,b = [sum(c[i] for c in samples)/len(samples) for i in range(3)]
            # The GLB's pale neutral swatch is stucco; medium gray is trim.
            is_wall = r > .70 and abs(g-r)<.03 and -.02<b-r<.14
            is_trim = .335 < r < .57 and .39 < b < .72 and .075 < b-r < .155 and abs(g-r)<.045
            is_dark = .20 < r < .34 and abs(g-r)<.035 and .035<b-r<.1
            is_glass = b-r > .20 and b>.73 and g-r>.09
            face.material_index = 1 if is_wall else (2 if is_glass else 0)
            for li,c in zip(face.loop_indices,samples):
                if is_wall:
                    value = min(.95,max(.84,.84+(c[0]-.70)*.40))
                    c = [value]*3
                elif is_trim:
                    shade = .82 + max(0,min(1,(c[0]-.335)/.24))*.14
                    c = [shade,shade*.96,shade*.84]
                elif is_dark:
                    shade = max(.0,min(1,(c[0]-.20)/.14))
                    c = [.14+shade*.10,.23+shade*.12,.25+shade*.14]
                colors.data[li].color = (*[linear(c0) for c0 in c],1)
            face.use_smooth = False
        # One source unit is ten metres; put footprint at y=0 on Godot import.
        for vtx in mesh.vertices: vtx.co *= 10
        o.name = name
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,name+'.glb'),export_format='GLB',export_yup=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
    print('CITY_EXPORT',name,manifest[name])
with open(os.path.join(OUT,'manifest.json'),'w') as f: json.dump(manifest,f,indent=2)
print('CITY_ASSETS_COMPLETE',len(names))
