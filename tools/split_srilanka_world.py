"""Filter obsolete decoration directly in GLB index buffers, preserving road bytes.
No quantization or vertex rewrite. Original Colombo GLB and track.json stay intact.
"""
from pathlib import Path
import json,struct,hashlib,math
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
data=(ROOT/'assets/models/lotus_coast.glb').read_bytes()
json_len=struct.unpack_from('<I',data,12)[0]
doc=json.loads(data[20:20+json_len]);off=20+json_len
bin_len=struct.unpack_from('<I',data,off)[0];binary=bytearray(data[off+8:off+8+bin_len])
track=json.loads((ROOT/'assets/track.json').read_text());points=np.array(track['points'])
ids=np.arange(0,len(points),20);t=points[(ids+1)%len(points)]-points[(ids-1)%len(points)];t/=np.linalg.norm(t,axis=1)[:,None]
normals=np.stack([-t[:,2],np.zeros(len(t)),t[:,0]],axis=1)
lamps=points[ids]-normals*12.6+np.array([0,4.7,.4])
def accessor(i):
 a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']];types={5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'};n={'SCALAR':1,'VEC3':3}[a['type']]
 return np.frombuffer(binary,dtype=types[a['componentType']],count=a['count']*n,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).copy().reshape((-1,n))
removed={};road_hash='';groups={}
for primitive in doc['meshes'][0]['primitives']:
 name=doc['materials'][primitive['material']]['name'];verts=accessor(primitive['attributes']['POSITION']);inds=accessor(primitive['indices']).reshape((-1,3));tri=verts[inds];centers=tri.mean(axis=1)
 mask=np.ones(len(inds),dtype=bool)
 if name=='road':road_hash=hashlib.sha256(verts.tobytes()+inds.tobytes()).hexdigest()
 elif name in ['trunk','leaf','leaflight']:mask[:]=False
 else:
  # Existing barriers, caps, and curb ribbons have explicit racing offsets.
  dist=((centers[:,None,[0,2]]-points[None,:,[0,2]])**2).sum(axis=2).min(axis=1)**.5
  curb=(dist>9.24)&(dist<10.35)&(centers[:,1]>.055)&(centers[:,1]<.075)
  wall=(dist>10.45)&(dist<11.65)&(centers[:,1]>.0)&(centers[:,1]<1.2)
  flag=np.zeros(len(inds),dtype=bool)
  if name in ['cyan','pink']:
   for p in lamps:
    delta=np.abs(tri-p);flag|=(delta[:,:,0].max(axis=1)<.71)&(delta[:,:,1].max(axis=1)<1.01)&(delta[:,:,2].max(axis=1)<.041)
  mask&=~(curb|wall|flag)
  if name in ['pink','gold']:mask&=~((centers[:,1]>.65)&(centers[:,1]<1.12)&(dist>12.5)&(dist<16))
 removed[name]=int((~mask).sum())
 if not mask.any():continue
 p=primitive.copy()
 if not mask.all():
  payload=inds[mask].astype('<u4').tobytes()
  while len(binary)%4:binary.append(0)
  view=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':len(binary),'byteLength':len(payload),'target':34963});binary.extend(payload)
  p['indices']=len(doc['accessors']);doc['accessors'].append({'bufferView':view,'componentType':5125,'count':int(mask.sum())*3,'type':'SCALAR'})
 group='RoadPreserved' if name=='road' else ('GroundPreserved' if name in ['grass','sand'] else 'ArchitecturePreserved')
 groups.setdefault(group,[]).append(p)
doc['meshes']=[{'name':name,'primitives':p} for name,p in groups.items()];doc['nodes']=[{'name':name,'mesh':i} for i,name in enumerate(groups)];doc['scenes']=[{'nodes':list(range(len(groups)))}];doc['scene']=0
doc['buffers'][0]['byteLength']=len(binary)
j=json.dumps(doc,separators=(',',':')).encode();j+=b' '*((-len(j))%4);binary+=b'\0'*((-len(binary))%4)
out=struct.pack('<III',0x46546c67,2,12+8+len(j)+8+len(binary))+struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(binary),0x004e4942)+binary
(ROOT/'assets/models/srilanka/world.glb').write_bytes(out)
report={'road_geometry_sha256':road_hash,'track_sha256':hashlib.sha256((ROOT/'assets/track.json').read_bytes()).hexdigest(),'removed_triangles':removed,'groups':list(groups),'original_world_preserved':True}
(ROOT/'docs/qa-srilanka/world-split.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report))
