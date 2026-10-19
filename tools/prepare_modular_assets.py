"""Offline, lossless car preparation; invoke Blender separately for driver poses.
All POSITION/NORMAL/UV/color accessor bytes and all embedded images are retained.
Only index buffers are partitioned into wheel groups; transforms normalize units.
"""
import copy, hashlib, json, math
from pathlib import Path
import numpy as np
from modular_glb import GLB, points, components

ROOT=Path(__file__).resolve().parents[1]
SOURCES=ROOT.parents[1]/'sources'
OUT=ROOT/'assets/models/modular';OUT.mkdir(parents=True,exist_ok=True)
MANIFEST=ROOT/'docs/modular-garage';MANIFEST.mkdir(parents=True,exist_ok=True)
FILES=[('duster','2011_dacia_duster','Dacia Duster'),('cyberpunk','cyberpunk_car','Cyberpunk GT'),('hover','cyberpunk_hovercar','Neon Hover'),('bigster','dacia_Bigster','Dacia Bigster'),('mclaren','mclaren_mp425','McLaren MP4-25'),('pony','pony_cartoon','Pony Cartoon'),('colombo_tuk','tuk_tuk_colombo','Colombo Tuk-Tuk')]

def prepare(key,stem,title):
    path=SOURCES/'cars_glb'/f'{stem}.glb';g=GLB(path);d=g.doc;world=g.worlds()
    # Gather connected primitive pieces in the original coordinate space.
    pieces=[];excluded=[]
    for ni,n in enumerate(d['nodes']):
        if 'mesh' not in n:continue
        for pi,p in enumerate(d['meshes'][n['mesh']]['primitives']):
            xyz=g.array(p['attributes']['POSITION']);faces=g.array(p['indices']).reshape(-1,3) if 'indices' in p else np.arange(len(xyz)).reshape(-1,3)
            if key=='pony' and n['mesh']==1:
                excluded.append({'node':n.get('name'),'material':'Ground_SG','triangles':len(faces),'reason':'Imported presentation ground only'});continue
            # Named assemblies are kept together; fused assets are partitioned.
            cs=components(xyz,faces) if key in ['bigster','mclaren','pony','colombo_tuk'] else [np.arange(len(faces))]
            for c in cs:
                f=faces[c];v=points(world[ni],xyz[np.unique(f)])
                pieces.append({'node':ni,'mesh':n['mesh'],'primitive':p,'faces':f,'center':(v.min(0)+v.max(0))/2,'extent':np.ptp(v,axis=0),'bounds':(v.min(0),v.max(0)),'name':n.get('name','mesh'),'wheel':None,'brake':False})
    anchors=[]
    if key in ['duster','cyberpunk']:
        for p in pieces:
            name=p['name'].lower()
            tire=('wheel_rubber' in name if key=='duster' else 'wheel ' in name)
            if tire and 'driving_wheel' not in name:
                anchors.append(p['center'])
    elif key=='bigster':anchors=[p['center'] for p in pieces if len(p['faces'])==80 and p['extent'][1]>100]
    elif key=='mclaren':anchors=[p['center'] for p in pieces if p['mesh']==1]
    elif key=='pony':anchors=[p['center'] for p in pieces if p['mesh']==0 and len(p['faces'])==320]
    elif key=='colombo_tuk':anchors=[p['center'] for p in pieces if 'llanta' in p['name'].lower()]
    expected=0 if key=='hover' else (3 if key=='colombo_tuk' else 4)
    assert len(anchors)==expected,(key,len(anchors))
    # All supplied models face +Z, except Bigster (+X). Rotate to Godot -Z.
    angle=math.pi/2 if key=='bigster' else math.pi
    rot=np.array([[math.cos(angle),0,math.sin(angle)],[0,1,0],[-math.sin(angle),0,math.cos(angle)]])
    corners=np.concatenate([np.array(p['bounds']) for p in pieces]);corners=corners@rot.T
    # Corners need transformed AABB extrema; these rotations are right angles.
    lo=corners.min(0);hi=corners.max(0)
    width=hi[0]-lo[0];scale=2.25/width
    if key=='hover':scale=2.8/width
    norm=np.eye(4);norm[:3,:3]=rot*scale;norm[:3,3]=np.array([-(lo[0]+hi[0])/2,-lo[1],-(lo[2]+hi[2])/2])*scale
    if key=='hover':norm[1,3]+=.20
    dims=(hi-lo)*scale
    anchors=sorted(anchors,key=lambda a:(float((rot@a)[2]),float((rot@a)[0])))
    wheeldata=[]
    for i,a in enumerate(anchors):
        normalized=points(norm,np.array([a]))[0]
        wheeldata.append({'name':f'wheel_{i}','pivot':normalized.tolist(),'steering':bool(normalized[2]<0),'radius':0.,'axis':[1,0,0]})
    for p in pieces:
        name=p['name'].lower();candidate=False
        if key=='duster':candidate='_wheel_' in name and 'driving_wheel' not in name
        elif key=='cyberpunk':candidate='wheel ' in name
        elif key=='bigster':candidate=len(p['faces'])==80 and p['extent'][1]>100
        elif key=='mclaren':candidate=p['mesh'] in [0,1,2,3,4]
        elif key=='pony':candidate=p['mesh']==0 and len(p['faces'])==320
        elif key=='colombo_tuk':candidate='rin_' in name or 'rin.001_' in name
        if candidate:
            i=min(range(len(anchors)),key=lambda i:np.linalg.norm(p['center']-anchors[i]))
            p['wheel']=i;p['brake']='brakes' in name or (key=='mclaren' and p['mesh'] in [3,4])
            r=p['extent'][1]*scale*.5
            wheeldata[i]['radius']=max(wheeldata[i]['radius'],r)
    # Merge index partitions with identical source node/material/motion policy.
    # This preserves draw-call batching while leaving every triangle untouched.
    batches={}
    for p in pieces:
        ident=(p['node'],id(p['primitive']),p['wheel'],p['brake'])
        if ident in batches:batches[ident]['faces']=np.concatenate([batches[ident]['faces'],p['faces']])
        else:batches[ident]=dict(p)
    pieces=list(batches.values())
    # Flatten static node transforms. No vertex attribute is transformed/rebuilt.
    nodes=[];meshes=[];roots=[];wheel_nodes=[];caliper_nodes={}
    for w in wheeldata:
        wheel_nodes.append(len(nodes));roots.append(len(nodes));nodes.append({'name':w['name'],'translation':w['pivot'],'children':[]})
    audit=[]
    for p in pieces:
        primitive=copy.deepcopy(p['primitive']);primitive['indices']=g.accessor(p['faces'].reshape(-1,1));mi=len(meshes)
        meshes.append({'name':p['name'],'primitives':[primitive]})
        m=norm@world[p['node']]
        if p['wheel'] is not None:
            w=wheeldata[p['wheel']];m[:3,3]-=np.array(w['pivot'])
            parent=wheel_nodes[p['wheel']]
            if p['brake']:
                # Calipers steer with the hub but sit outside the rotating group.
                if p['wheel'] not in caliper_nodes:
                    caliper_nodes[p['wheel']]=len(nodes)
                    nodes.append({'name':w['name']+'_caliper','translation':w['pivot'],'children':[]});roots.append(caliper_nodes[p['wheel']])
                stationary=caliper_nodes[p['wheel']]
                parent=stationary
            nodes[parent]['children'].append(len(nodes))
        else:roots.append(len(nodes))
        nodes.append({'name':p['name']+'_part_'+str(mi),'mesh':mi,'matrix':m.T.reshape(-1).tolist()})
        audit.append({'source_node':p['node'],'source_attributes':p['primitive']['attributes'],'material':p['primitive'].get('material'),'triangles':len(p['faces']),'wheel':p['wheel'],'caliper':p['brake']})
    original_meshes=d['meshes'];d['meshes']=meshes;d['nodes']=nodes;d['scenes']=[{'name':title,'nodes':roots}];d['scene']=0
    d.pop('animations',None);d.pop('skins',None);d.pop('cameras',None)
    target=OUT/f'{key}.glb';g.save(target)
    source=GLB(path)
    # Byte-for-byte accessor and texture equality: stronger than bounds/triangle tests.
    for mesh in g.doc['meshes']:
        for p in mesh['primitives']:
            for attr,index in p['attributes'].items():assert np.array_equal(g.array(index),source.array(index)),(key,attr)
    assert g.doc.get('materials')==source.doc.get('materials')
    for i in range(len(d.get('images',[]))):assert g.image(i)==source.image(i)
    total=sum(len(p['faces']) for p in pieces)
    original=sum(len(source.array(p['indices']))//3 for n in source.doc['nodes'] if 'mesh' in n for p in source.doc['meshes'][n['mesh']]['primitives'])
    assert total+sum(x['triangles'] for x in excluded)==original
    result={'id':key,'name':title,'source':str(path.relative_to(SOURCES)).replace('\\','/'),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'prepared_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'license':source.doc['asset'].get('extras',{}),'normalization':norm.T.reshape(-1).tolist(),'bounds':dims.tolist(),'wheels':wheeldata,'source_triangles':original,'runtime_triangles':total,'excluded':excluded,'accessors_images_materials_identical':True,'parts':audit}
    print(key,'triangles',total,'wheels',len(wheeldata),'bounds',np.round(dims,2),'radii',[round(w['radius'],3) for w in wheeldata],flush=True)
    return result

if __name__=='__main__':
    manifest=[prepare(*entry) for entry in FILES]
    for path in (SOURCES/'driver_glb').glob('*.glb'):
        g=GLB(path);manifest.append({'source':'driver_glb/'+path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'license':g.doc['asset'].get('extras',{})})
        if path.stem=='Shaven_Leo_driver':
            mat=next(m for m in g.doc['materials'] if m['name']=='Wolf3D_Headwear')
            tex=mat['extensions']['KHR_materials_pbrSpecularGlossiness']['diffuseTexture']['index']
            (OUT/'helmet_driver.png').write_bytes(g.image(g.doc['textures'][tex]['source']))
    (MANIFEST/'asset-provenance.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    (OUT/'prepared-specs.json').write_text(json.dumps(manifest[:7],indent=2),encoding='utf-8')
