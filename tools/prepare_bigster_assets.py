"""v1.6 derivatives. Read v1.5 GLBs; retain originals, UVs and face topology.

Body sections map between axle stations. Wheels use a uniform transform around
their own hub, never the body's non-uniform dimensional correction.
"""
from pathlib import Path
import copy, hashlib, io, json, re
import numpy as np
from PIL import Image
from modular_glb import GLB, points
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models/bigster';OUT.mkdir(parents=True,exist_ok=True)
SPECS={x['id']:x for x in json.loads((ROOT/'assets/models/modular/prepared-specs.json').read_text())}

def mat(name,color,metal=0.,rough=.6,glass=False):
    m={'name':name,'pbrMetallicRoughness':{'baseColorFactor':color,'metallicFactor':metal,'roughnessFactor':rough}}
    if glass:m.update(alphaMode='BLEND',doubleSided=True)
    return m

def prepare(key):
    source=ROOT/f'assets/models/modular/{key}.glb';g=GLB(source);old=copy.deepcopy(g.doc);world=g.worlds();spec=SPECS[key]
    length,height,width={'duster':(4.315,1.680,2.0),'bigster':(4.570,1.712,2.069),'colombo_tuk':(2.635,1.700,1.300)}[key]
    oldlength=spec['bounds'][2];oldheight=spec['bounds'][1];oldwidth=spec['bounds'][0]
    axle0=min(w['pivot'][2] for w in spec['wheels']);axle1=max(w['pivot'][2] for w in spec['wheels'])
    wb={'duster':2.673,'bigster':2.702,'colombo_tuk':2.000}[key]
    newfront=-wb/2;newrear=wb/2
    xscale=width/oldwidth;yscale=height/oldheight
    if key=='duster':xscale=yscale=length/oldlength
    oldstations=np.array([-oldlength/2,axle0,axle1,oldlength/2])
    newstations=np.array([-length/2,newfront,newrear,length/2])
    def body(p):
        r=p.copy();r[:,0]*=xscale;r[:,1]*=yscale;r[:,2]=np.interp(p[:,2],oldstations,newstations);return r
    newwheels=[]
    for w in spec['wheels']:
        target=body(np.array([w['pivot']]))[0]
        radius=w['radius']*(length/oldlength) if key=='duster' else (.355 if key=='bigster' else .2032)
        if key=='bigster':target[0]=np.sign(target[0])*.780
        if key=='colombo_tuk' and abs(target[0])>.1:target[0]=np.sign(target[0])*.515
        target[1]=radius
        newwheels.append(dict(pivot=target.tolist(),radius=radius))
    # Keep authored map bindings where useful; add semantic materials, not a
    # global atlas tint that turns lamps and tires into painted bodywork.
    mats=copy.deepcopy(old['materials'])
    for m in mats:
        m.pop('extensions',None);p=m.setdefault('pbrMetallicRoughness',{});n=m.get('name','').lower()
        if key=='duster':
            if n=='varnish':p.update(baseColorFactor=[.92,.94,.95,1],metallicFactor=.45,roughnessFactor=.23)
            elif 'glass'==n:p.update(baseColorFactor=[.18,.28,.33,.22],metallicFactor=0,roughnessFactor=.08);m.update(alphaMode='BLEND',doubleSided=True)
            elif 'rubber' in n:p.update(metallicFactor=0,roughnessFactor=.93)
            elif n in ['chrome','metal','mirror_left','mirror_right']:p.update(metallicFactor=.82,roughnessFactor=.22)
            elif 'lamp' in n or 'light' in n:p.update(roughnessFactor=.18);m['emissiveFactor']=[.12,.08,.04]
            else:p.update(metallicFactor=0,roughnessFactor=.8)
        elif key=='colombo_tuk':
            if n=='glass':m.update(mat('Colombo glass',[.19,.27,.3,.22],rough=.09,glass=True))
            elif 'llanta' in n:p.update(metallicFactor=0,roughnessFactor=.94)
            elif 'rin' in n:p.update(metallicFactor=.75,roughnessFactor=.3)
            else:p.pop('metallicRoughnessTexture',None);p.update(metallicFactor=.2,roughnessFactor=.46)
    if key=='bigster':mats[0]['pbrMetallicRoughness'].update(baseColorFactor=[.18,.21,.24,1],metallicFactor=.55,roughnessFactor=.28)
    paint=len(mats);mats.append(copy.deepcopy(mats[0]) if key=='bigster' else mat('Paint',[.24,.28,.30,1],.65,.24));mats[-1]['name']='Graphite paint'
    glass=len(mats);mats.append(mat('Clear automotive glass',[.13,.22,.26,.24],rough=.08,glass=True))
    trim=len(mats);mats.append(copy.deepcopy(mats[0]) if key=='bigster' else mat('Textured black trim',[.026,.032,.035,1],rough=.78));mats[-1]['name']='Unpainted trim';mats[-1]['pbrMetallicRoughness'].update(metallicFactor=0,roughnessFactor=.78)
    canopy=len(mats);mats.append(mat('Matte woven canopy',[.025,.025,.023,1],rough=.94))
    if key=='bigster':
        tire_mat=len(mats);mats.append(copy.deepcopy(old['materials'][0]) if key=='bigster' else mat('Rubber',[.02,.02,.02,1]))
        mats[-1].pop('extensions',None);mats[-1]['name']='Wheel rubber';mats[-1]['pbrMetallicRoughness'].update(baseColorFactor=[1,1,1,1],metallicFactor=0,roughnessFactor=.93)
        alloy_mat=len(mats);mats.append(copy.deepcopy(mats[tire_mat]));mats[-1]['name']='Wheel alloy';mats[-1]['pbrMetallicRoughness'].update(metallicFactor=.82,roughnessFactor=.24)
        lamp_mat=len(mats);mats.append(copy.deepcopy(mats[tire_mat]));mats[-1]['name']='Headlamp lens';mats[-1]['pbrMetallicRoughness'].update(roughnessFactor=.18);mats[-1]['emissiveFactor']=[.35,.35,.32]
        if key=='bigster':mats[-1]['emissiveTexture']={'index':0}
        rear_mat=len(mats);mats.append(copy.deepcopy(mats[lamp_mat]));mats[-1]['name']='Tail lamp lens';mats[-1]['emissiveFactor']=[.8,.04,.02]
    image=np.asarray(Image.open(io.BytesIO(g.image(0))).convert('RGB'))/255. if key=='bigster' else None
    parents={c:i for i,n in enumerate(old['nodes']) for c in n.get('children',[])}
    nodes=[{'name':'VehicleMetres','children':[]}];meshes=[];groups={};counts={}
    def group_for(i):
        while True:
            n=old['nodes'][i].get('name','')
            if n.startswith('wheel_'):return n
            if i not in parents:return 'body'
            i=parents[i]
    for ni,n in enumerate(old['nodes']):
        if 'mesh' not in n:continue
        group=group_for(ni);wheelnum=int(group.split('_')[1]) if group.startswith('wheel_') else None
        if group not in groups:
            groups[group]=len(nodes);nodes.append({'name':group,'children':[]});nodes[0]['children'].append(groups[group])
        prims=[]
        for p in old['meshes'][n['mesh']]['primitives']:
            faces=g.array(p['indices']).reshape(-1,3).astype(int);xyz=points(world[ni],g.array(p['attributes']['POSITION']))
            out=body(xyz)
            scale=np.array([xscale,yscale,(newrear-newfront)/(axle1-axle0)])
            if wheelnum is not None:
                w=spec['wheels'][wheelnum];nw=newwheels[wheelnum];factor=nw['radius']/w['radius']
                out=(xyz-np.array(w['pivot']))*factor+np.array(nw['pivot']);scale[:]=factor
            assignments=np.full(len(faces),p.get('material',0),int)
            centers=out[faces].mean(1)
            if key=='bigster' and wheelnum is not None:
                hub=np.array(newwheels[wheelnum]['pivot']);radial=np.linalg.norm(centers[:,[1,2]]-hub[[1,2]],axis=1)
                assignments[:]=np.where(radial>newwheels[wheelnum]['radius']*.74,tire_mat,alloy_mat)
            if key=='bigster' and wheelnum is None:
                uv=g.array(p['attributes']['TEXCOORD_0'])[faces].mean(1)
                rgb=image[(np.clip(uv[:,1],0,.9999)*image.shape[0]).astype(int),(np.clip(uv[:,0],0,.9999)*image.shape[1]).astype(int)]
                brightness=rgb.mean(1);spread=np.ptp(rgb,axis=1)
                # Large neutral panes above the beltline; keep painted pillars,
                # roof, bright lamps, red tail lights and atlas trim opaque.
                normal=np.cross(out[faces[:,1]]-out[faces[:,0]],out[faces[:,2]]-out[faces[:,0]])
                area=np.linalg.norm(normal,axis=1)*.5
                normal/=np.maximum(np.linalg.norm(normal,axis=1,keepdims=True),1e-10)
                win=(centers[:,1]>1.18)&(centers[:,1]<1.60)&(centers[:,2]>-.95)&(centers[:,2]<2.12)&(area>.045)&(np.abs(normal[:,1])<.8)
                assignments[(brightness>.58)&(spread<.15)]=paint
                assignments[brightness<.14]=trim
                assignments[win]=glass
                assignments[(centers[:,2]<-1.9)&(centers[:,1]>.55)&(centers[:,1]<1.10)&(np.abs(centers[:,0])>.43)&(brightness>.65)&(spread<.15)]=lamp_mat
                assignments[(centers[:,2]>1.95)&(rgb[:,0]>rgb[:,1]*1.8)&(rgb[:,0]>.35)]=rear_mat
            if key=='colombo_tuk' and wheelnum is None:
                assignments[(centers[:,1]>1.28)&(centers[:,2]>-.8)]=canopy
            for mi in np.unique(assignments):
                f=faces[assignments==mi];used,remap=np.unique(f,return_inverse=True);attrs={}
                for name,accessor in p['attributes'].items():
                    value=g.array(accessor)[used]
                    if name=='POSITION':value=out[used]
                    elif name=='NORMAL':
                        value=value@np.linalg.inv(world[ni][:3,:3]);value/=scale;value/=np.maximum(np.linalg.norm(value,axis=1,keepdims=True),1e-10)
                    a=old['accessors'][accessor];attrs[name]=g.accessor(value,a['type'],a['componentType'])
                    if a.get('normalized'):g.doc['accessors'][attrs[name]]['normalized']=True
                    if name=='POSITION':g.doc['accessors'][attrs[name]].update(min=value.min(0).tolist(),max=value.max(0).tolist())
                prims.append({'attributes':attrs,'indices':g.accessor(remap.astype(np.uint32).ravel()),'material':int(mi)})
                counts[mats[mi]['name']]=counts.get(mats[mi]['name'],0)+len(f)
        idx=len(nodes);nodes.append({'name':n.get('name','part'),'mesh':len(meshes)});nodes[groups[group]]['children'].append(idx);meshes.append({'primitives':prims})
    if key=='bigster':
        # A lightweight cabin is required behind the newly transparent panes.
        def box(name,center,size):
            corners=np.array([[x,y,z] for x in [-.5,.5] for y in [-.5,.5] for z in [-.5,.5]])*np.array(size)+center
            faces=np.array([[0,1,3],[0,3,2],[4,6,7],[4,7,5],[0,4,5],[0,5,1],[2,3,7],[2,7,6],[0,2,6],[0,6,4],[1,5,7],[1,7,3]])
            pos=corners[faces].reshape(-1,3);normal=np.repeat(np.cross(corners[faces[:,1]]-corners[faces[:,0]],corners[faces[:,2]]-corners[faces[:,0]]),3,axis=0);normal/=np.linalg.norm(normal,axis=1,keepdims=True)
            attrs={'POSITION':g.accessor(pos,'VEC3',5126),'NORMAL':g.accessor(normal,'VEC3',5126)}
            g.doc['accessors'][attrs['POSITION']].update(min=pos.min(0).tolist(),max=pos.max(0).tolist())
            nodes[0]['children'].append(len(nodes));nodes.append({'name':name,'mesh':len(meshes)});meshes.append({'primitives':[{'attributes':attrs,'indices':g.accessor(np.arange(len(pos))),'material':trim}]})
        box('CabinFloor',[0,.46,.35],[1.60,.08,2.60])
        box('Dashboard',[0,.95,-.71],[1.55,.20,.29])
        for x in [-.37,.37]:
            box('SeatCushion',[x,.62,.10],[.46,.12,.48]);box('SeatBack',[x,.94,.38],[.46,.64,.11]);box('Headrest',[x,1.28,.38],[.30,.18,.13])
        box('RearBench',[0,.68,1.20],[1.35,.2,.5])
        box('SteeringColumn',[-.37,.95,-.53],[.08,.08,.25])
        box('SteeringRimTop',[-.37,1.12,-.44],[.30,.035,.035]);box('SteeringRimBottom',[-.37,.92,-.44],[.30,.035,.035])
        box('SteeringRimLeft',[-.52,1.02,-.44],[.035,.20,.035]);box('SteeringRimRight',[-.22,1.02,-.44],[.035,.20,.035])
    g.doc.update(nodes=nodes,meshes=meshes,materials=mats,scenes=[{'nodes':[0]}],scene=0)
    g.doc.pop('extensionsRequired',None);g.doc.pop('animations',None)
    g.save(OUT/f'{key}.glb')
    # Bindings include the chassis grounding transform, so hub rotations do not
    # orbit the original +8 cm chassis offset.
    path=ROOT/f'assets/catalog/vehicle_{key}.tres';text=path.read_text(encoding='utf8').replace(f'modular/{key}.glb',f'bigster/{key}.glb')
    for i,w in enumerate(newwheels):
        a=text.index(f'[sub_resource type="Resource" id="w{i}"]');b=text.find('\n[',a+1);b=len(text) if b<0 else b
        chunk=text[a:b];pivot=np.array(w['pivot']);pivot[1]+=.08
        chunk=re.sub(r'pivot = Vector3\([^\n]+',f'pivot = Vector3({pivot[0]:.8f}, {pivot[1]:.8f}, {pivot[2]:.8f})',chunk)
        chunk=re.sub(r'radius = [^\n]+',f'radius = {w["radius"]:.9f}',chunk);text=text[:a]+chunk+text[b:]
    def setting(name,value):
        nonlocal text
        if re.search('^'+name+r' = ',text,re.M):text=re.sub('^'+name+r' = [^\n]+',name+' = '+value,text,flags=re.M)
        else:text+='\n'+name+' = '+value+'\n'
    setting('collision_size',f'Vector3({min(width,1.85):.4f}, {height:.4f}, {length:.4f})')
    setting('collision_position',f'Vector3(0, {height/2+.08:.4f}, 0)')
    setting('preview_target',f'Vector3(0, {height*.48:.4f}, 0)');setting('preview_distance','8.1' if key=='bigster' else '8.0')
    setting('camera_height','0.35')
    setting('exhausts',f'PackedVector3Array(-0.42, 0.40, {length*.46:.4f}, 0.42, 0.40, {length*.46:.4f})')
    if key in ['duster','bigster']:
        setting('max_speed','45.8333333333' if key=='duster' else '50.0');setting('boosted_speed','55.0' if key=='duster' else '62.5')
        setting('driver_policy','2');setting('fixed_driver_id','&"human"');setting('ai_lateral_acceleration','13.5')
        setting('driver_fits','{"human": Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.37, 0.70, -0.08)}')
    if key=='bigster':setting('electric_boost','true');setting('braking_regeneration','0.035');setting('display_name','"Dacia Bigster Hybrid"')
    path.write_text(text,encoding='utf8')
    return {'id':key,'source':source.relative_to(ROOT).as_posix(),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'prepared_sha256':hashlib.sha256((OUT/f'{key}.glb').read_bytes()).hexdigest(),'target_metres':{'length':length,'width_with_mirrors':width,'height':height,'wheelbase':wb},'wheels':newwheels,'material_triangles':counts,'method':'Axle-station body mapping; independently uniformly scaled tire/rim groups; original triangle topology and UVs retained. Bigster is the supplied 2024-Duster-derived approximation.'}

if __name__=='__main__':
    result=[prepare(k) for k in ['duster','bigster','colombo_tuk']]
    (OUT/'derivative-specs.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    print(json.dumps(result,indent=2))
