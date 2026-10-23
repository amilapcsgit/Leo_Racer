"""Extract attributed premade buildings/props, retaining UVs and materials.

Only scene transforms, units, origin, texture resolution and mesh partitioning
change. The user's original GLBs are read-only inputs.
"""
from __future__ import annotations
from pathlib import Path
import copy,hashlib,io,json,struct
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from modular_glb import GLB,points,components
ROOT=Path(__file__).resolve().parents[1]
INPUT=Path(r'C:\Users\amilapcs\Downloads\Leo Racer\colombo-city')
OUT=ROOT/'assets/models/colombo_city'
OUT.mkdir(parents=True,exist_ok=True)
TEXTURES=OUT/'textures';TEXTURES.mkdir(exist_ok=True)
manifest={'format':1,'buildings':[],'props':[],'sources':[],'excluded':['city_at_night_low_poly_skyscrapers.glb: rights not documented for redistribution','colombo-city source/Untitled.glb: no embedded provenance']}

def materials(g,primitives):
    ids=sorted({p.get('material',0) for p in primitives});mapping={v:i for i,v in enumerate(ids)}
    mats=[copy.deepcopy(g.doc['materials'][i]) for i in ids];texture_ids=set()
    def gather(value):
        if isinstance(value,dict):
            for key,item in value.items():
                if key.lower().endswith('texture') and isinstance(item,dict) and 'index' in item:texture_ids.add(item['index'])
                else:gather(item)
        elif isinstance(value,list):
            for item in value:gather(item)
    for mat in mats:gather(mat)
    texture_ids=sorted(texture_ids);texture_mapping={v:i for i,v in enumerate(texture_ids)}
    def rewrite(value):
        if isinstance(value,dict):
            for key,item in value.items():
                if key.lower().endswith('texture') and isinstance(item,dict) and 'index' in item:item['index']=texture_mapping[item['index']]
                else:rewrite(item)
        elif isinstance(value,list):
            for item in value:rewrite(item)
    for mat in mats:rewrite(mat)
    textures=[copy.deepcopy(g.doc['textures'][i]) for i in texture_ids]
    image_ids=sorted({t['source'] for t in textures});image_mapping={v:i for i,v in enumerate(image_ids)}
    images=[]
    for i in image_ids:
        source=Image.open(io.BytesIO(g.image(i))).convert('RGBA')
        source.thumbnail((2048,2048),Image.Resampling.LANCZOS)
        buffer=io.BytesIO();source.save(buffer,format='PNG',optimize=True)
        payload=buffer.getvalue();name=hashlib.sha256(payload).hexdigest()[:20]+'.png'
        target=TEXTURES/name
        if not target.exists():target.write_bytes(payload)
        images.append({'uri':'textures/'+name})
    for tex in textures:tex['source']=image_mapping[tex['source']]
    return mapping,mats,textures,images

def export(g,node_index,scale,name,category,faces=None):
    node=g.doc['nodes'][node_index];source_primitives=g.doc['meshes'][node['mesh']]['primitives']
    transform=g.worlds()[node_index]
    all_points=np.concatenate([points(transform,g.array(p['attributes']['POSITION'])) for p in source_primitives])
    if faces is not None:all_points=points(transform,g.array(source_primitives[0]['attributes']['POSITION']))[np.unique(faces)]
    low=all_points.min(axis=0);high=all_points.max(axis=0);origin=(low+high)/2;origin[1]=low[1]
    mapping,mats,textures,images=materials(g,source_primitives)
    doc={'asset':copy.deepcopy(g.doc['asset']),'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'name':name,'mesh':0}],
         'meshes':[{'name':name,'primitives':[]}],'materials':mats,'textures':textures,'images':images,
         'samplers':copy.deepcopy(g.doc.get('samplers',[])),'bufferViews':[],'accessors':[]}
    if g.doc.get('extensionsUsed'):doc['extensionsUsed']=g.doc['extensionsUsed']
    binary=bytearray()
    def accessor(values,kind):
        values=np.asarray(values,dtype='<u4' if kind=='SCALAR' else '<f4');payload=values.tobytes()
        binary.extend(b'\0'*(-len(binary)%4));offset=len(binary);binary.extend(payload)
        vi=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(payload)})
        result={'bufferView':vi,'componentType':5125 if kind=='SCALAR' else 5126,'count':len(values),'type':kind}
        if kind=='VEC3':result.update(min=values.min(axis=0).tolist(),max=values.max(axis=0).tolist())
        ai=len(doc['accessors']);doc['accessors'].append(result);return ai
    triangles=0
    for primitive in source_primitives:
        indices=g.array(primitive['indices']).reshape(-1,3) if 'indices' in primitive else np.arange(g.doc['accessors'][primitive['attributes']['POSITION']]['count']).reshape(-1,3)
        if faces is not None:indices=faces
        used,remap=np.unique(indices,return_inverse=True);attrs={}
        for key,index in primitive['attributes'].items():
            values=g.array(index)[used].astype(float)
            if key=='POSITION':values=(points(transform,values)-origin)*scale
            elif key=='NORMAL':
                values=values@np.linalg.inv(transform[:3,:3]);values/=np.maximum(np.linalg.norm(values,axis=1)[:,None],1e-10)
            elif key=='TANGENT':
                values[:,:3]=values[:,:3]@transform[:3,:3].T;values[:,:3]/=np.maximum(np.linalg.norm(values[:,:3],axis=1)[:,None],1e-10)
            attrs[key]=accessor(values,g.doc['accessors'][index]['type'])
        doc['meshes'][0]['primitives'].append({'attributes':attrs,'indices':accessor(remap.reshape(-1),'SCALAR'),'material':mapping[primitive.get('material',0)]})
        triangles+=len(indices)
    doc['buffers']=[{'byteLength':len(binary)}]
    text=json.dumps(doc,separators=(',',':')).encode();text+=b' '*(-len(text)%4);binary+=b'\0'*(-len(binary)%4)
    payload=struct.pack('<III',0x46546c67,2,28+len(text)+len(binary))+struct.pack('<II',len(text),0x4e4f534a)+text+struct.pack('<II',len(binary),0x004e4942)+binary
    target=OUT/(name+'.glb');target.write_bytes(payload)
    entry={'id':name,'path':'res://'+target.relative_to(ROOT).as_posix(),'width':float((high[0]-low[0])*scale),'height':float((high[1]-low[1])*scale),'depth':float((high[2]-low[2])*scale),'triangles':triangles,'source_node':node.get('name'),'source':g.path.name,'sha256':hashlib.sha256(payload).hexdigest()}
    manifest[category].append(entry)
    return entry

def prepare_legacy():
    for filename,prefix,scale in [('city_game_ready_free.glb','colombo_lowrise',6.),('low-poly_city_buildings.glb','colombo_tower',40.)]:
        g=GLB(INPUT/filename);manifest['sources'].append({'file':filename,'sha256':hashlib.sha256(g.path.read_bytes()).hexdigest(),**g.doc['asset']['extras']})
        world=g.worlds();count=0
        for i,node in enumerate(g.doc['nodes']):
            if 'mesh' not in node:continue
            xyz=np.concatenate([points(world[i],g.array(p['attributes']['POSITION'])) for p in g.doc['meshes'][node['mesh']]['primitives']]);size=np.ptp(xyz,axis=0)
            if prefix.endswith('lowrise'):
                if size[1]<1.9 or size[0]<3.5:continue
            elif size[1]<.35 or size[0]<.12:continue
            export(g,i,scale,f'{prefix}_{count:02d}','buildings');count+=1

    g=GLB(INPUT/'city_infrastructure_map_3.glb')
    manifest['sources'].append({'file':g.path.name,'sha256':hashlib.sha256(g.path.read_bytes()).hexdigest(),**g.doc['asset']['extras']})
    for i,node in enumerate(g.doc['nodes']):
        if 'Railing' not in node.get('name',''):continue
        primitive=g.doc['meshes'][node['mesh']]['primitives'][0]
        xyz=g.array(primitive['attributes']['POSITION']);indices=g.array(primitive['indices']).reshape(-1,3)
        world=points(g.worlds()[i],xyz)
        for part in components(world,indices):
            faces=indices[part];size=np.ptp(world[np.unique(faces)],axis=0)
            if 2<max(size[0],size[2])<35 and .3<size[1]<5:
                export(g,i,1.,f'colombo_railing_{len(manifest["props"]):02d}','props',faces)
                if len(manifest['props'])>=4:break
        if len(manifest['props'])>=4:break

    # Recover original custom architecture without ground or obsolete road triangles.
    original=GLB(ROOT/'assets/models/srilanka/world.glb')
    architecture=next(i for i,m in enumerate(original.doc['meshes']) if m.get('name')=='ArchitecturePreserved')
    # Recover the exact pavilion and reflecting pool, excluding obsolete race furniture.
    retained=[];retained_triangles=0
    for primitive in original.doc['meshes'][architecture]['primitives']:
        xyz=original.array(primitive['attributes']['POSITION']);faces=original.array(primitive['indices']).reshape(-1,3);tri=xyz[faces]
        pavilion=(np.abs(tri[:,:,0]).max(axis=1)<26)&(tri[:,:,2].min(axis=1)>22)&(tri[:,:,2].max(axis=1)<46)
        pool=((tri[:,:,0]**2+(tri[:,:,2]+25)**2).max(axis=1)<25.1**2)&(tri[:,:,1].max(axis=1)<1.)
        selected=faces[pavilion|pool]
        if not len(selected):continue
        used,remap=np.unique(selected,return_inverse=True);part=copy.deepcopy(primitive);part['attributes']={}
        for key,index in primitive['attributes'].items():
            attribute=original.doc['accessors'][index]
            part['attributes'][key]=original.accessor(original.array(index)[used],attribute['type'],attribute['componentType'])
        part['indices']=original.accessor(remap.reshape(-1));retained.append(part);retained_triangles+=len(selected)
    original.doc['meshes']=[{'name':'PavilionAndReflectingPoolPreserved','primitives':retained}]
    original.doc['nodes']=[{'name':'CustomColomboArchitecturePreserved','mesh':0}];original.doc['scenes']=[{'nodes':[0]}];original.doc['scene']=0
    manifest['custom_architecture']={'retained_triangles':retained_triangles,'source':'assets/models/srilanka/world.glb','treatment':'Exact retained vertex attributes and triangles; obsolete track, start arch, boulders, sails and track furniture excluded.'}
    original.save(OUT/'custom_architecture.glb')

    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (ROOT/'licenses/colombo-buildings.txt').write_text('Colombo City building and infrastructure library\n\n'+ '\n\n'.join(f'{s["title"]}\nAuthor: {s["author"]}\nSource: {s["source"]}\nLicense: {s["license"]}\nChanges: separated reusable meshes, metre normalization, ground-level origins, shared resized textures; original UVs/material assignments retained.' for s in manifest['sources'])+'\n\nCC BY 4.0: https://creativecommons.org/licenses/by/4.0/\n',encoding='utf-8')
    print('CITY_BUILDINGS',len(manifest['buildings']),'reusable models;',len(manifest['props']),'infrastructure pieces;',len(list(TEXTURES.glob('*.png'))),'shared textures')

if __name__ == "__main__":
    prepare_legacy()
