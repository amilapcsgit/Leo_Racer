"""Independent measurements of the actual indexed runtime geometry."""
from pathlib import Path
import hashlib,json,sys
import numpy as np
from modular_glb import GLB,points
ROOT=Path(__file__).resolve().parents[1];errors=[];rows=[]
specs=json.loads((ROOT/'assets/models/bigster/derivative-specs.json').read_text())
for s in specs:
    key=s['id'];g=GLB(ROOT/f'assets/models/bigster/{key}.glb');world=g.worlds()
    def geometry(i):
        n=g.doc['nodes'][i];result=[]
        if 'mesh' in n:
            for p in g.doc['meshes'][n['mesh']]['primitives']:
                result.append(points(world[i],g.array(p['attributes']['POSITION'])[np.unique(g.array(p['indices']))]))
        for child in n.get('children',[]):result.extend(geometry(child))
        return result
    xyz=np.concatenate(geometry(0));extent=np.ptp(xyz,axis=0);target=s['target_metres']
    if abs(extent[2]-target['length'])>.012 or abs(extent[1]-target['height'])>.015 or abs(extent[0]-target['width_with_mirrors'])>.02:errors.append(key+': measured exterior dimensions')
    wheelrows=[]
    for wi,w in enumerate(s['wheels']):
        index=next(i for i,n in enumerate(g.doc['nodes']) if n.get('name')==f'wheel_{wi}')
        tire=np.concatenate(geometry(index));ex=np.ptp(tire,axis=0);hub=(tire.min(0)+tire.max(0))*.5
        if abs(ex[1]-ex[2])>.018 or abs(ex[1]*.5-w['radius'])>.012:errors.append(key+': elliptical or wrong-radius wheel '+str(wi))
        if np.linalg.norm(hub-np.array(w['pivot']))>.025:errors.append(key+': wheel hub mismatch '+str(wi))
        wheelrows.append({'hub':hub.tolist(),'radius_y':float(ex[1]*.5),'radius_z':float(ex[2]*.5)})
    wb=max(w['hub'][2] for w in wheelrows)-min(w['hub'][2] for w in wheelrows)
    if abs(wb-target['wheelbase'])>.012:errors.append(key+': wheelbase')
    if key=='bigster':
        rubber=next(m for m in g.doc['materials'] if m.get('name')=='Wheel rubber')['pbrMetallicRoughness']
        if rubber['metallicFactor']!=0 or rubber['roughnessFactor']<.8:errors.append('Bigster rubber material')
        if s['material_triangles'].get('Headlamp lens',0)==0 or s['material_triangles'].get('Tail lamp lens',0)==0:errors.append('Bigster lamp material separation')
    original=ROOT/s['source']
    if hashlib.sha256(original.read_bytes()).hexdigest()!=s['source_sha256']:errors.append(key+': stable v1.5 model changed')
    glass=[m for m in g.doc['materials'] if 'glass' in m.get('name','').lower()]
    if not glass or not all(m.get('alphaMode')=='BLEND' and 'KHR_materials_transmission' not in m.get('extensions',{}) for m in glass):errors.append(key+': compatibility glass')
    rows.append({'id':key,'measured_width_height_length':extent.tolist(),'wheelbase':wb,'wheels':wheelrows,'glass':'alpha blend, no transmission dependency'})
result={'status':'PASS' if not errors else 'FAIL','errors':errors,'vehicles':rows,'note':'Bigster is a proportion-corrected approximation of the supplied body, not a newly licensed authentic Bigster model.'}
(ROOT/'docs/qa-bigster/asset-measurements.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2));sys.exit(bool(errors))
