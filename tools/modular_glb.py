"""Lossless glTF accessors and component partitioning. Source files are never edited."""
import copy, json, struct
from pathlib import Path
import numpy as np

DT = {5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}
NC = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}

class GLB:
    def __init__(self, path):
        self.path = Path(path)
        data = self.path.read_bytes()
        size = struct.unpack_from('<I',data,12)[0]
        self.doc = json.loads(data[20:20+size])
        self.bin = bytearray(data[28+size:])
    def array(self, index):
        a=self.doc['accessors'][index]; v=self.doc['bufferViews'][a['bufferView']]
        dt=np.dtype(DT[a['componentType']]); width=NC[a['type']]
        return np.ndarray((a['count'],width),dtype=dt,buffer=self.bin,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',width*dt.itemsize),dt.itemsize)).copy()
    def accessor(self, values, kind='SCALAR', component=5125):
        values=np.asarray(values,dtype=DT[component]); raw=values.tobytes()
        self.bin.extend(b'\0'*(-len(self.bin)%4)); offset=len(self.bin); self.bin.extend(raw)
        vi=len(self.doc['bufferViews']); self.doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(raw)})
        ai=len(self.doc['accessors']); self.doc['accessors'].append({'bufferView':vi,'componentType':component,'count':len(values),'type':kind})
        return ai
    def worlds(self):
        result={}
        def visit(i,parent):
            n=self.doc['nodes'][i]
            if 'matrix' in n: local=np.array(n['matrix']).reshape(4,4).T
            else:
                x,y,z,w=n.get('rotation',[0,0,0,1]); local=np.eye(4)
                local[:3,:3]=np.array([[1-2*y*y-2*z*z,2*x*y-2*z*w,2*x*z+2*y*w],[2*x*y+2*z*w,1-2*x*x-2*z*z,2*y*z-2*x*w],[2*x*z-2*y*w,2*y*z+2*x*w,1-2*x*x-2*y*y]])@np.diag(n.get('scale',[1,1,1]))
                local[:3,3]=n.get('translation',[0,0,0])
            result[i]=parent@local
            for c in n.get('children',[]): visit(c,result[i])
        for i in self.doc['scenes'][self.doc.get('scene',0)]['nodes']: visit(i,np.eye(4))
        return result
    def image(self,index):
        view=self.doc['bufferViews'][self.doc['images'][index]['bufferView']]
        return bytes(self.bin[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']])
    def save(self,path):
        self.doc['buffers']=[{'byteLength':len(self.bin)}]
        raw=json.dumps(self.doc,separators=(',',':')).encode();raw+=b' '*(-len(raw)%4)
        data=bytes(self.bin);data+=b'\0'*(-len(data)%4)
        Path(path).write_bytes(struct.pack('<III',0x46546c67,2,28+len(raw)+len(data))+struct.pack('<II',len(raw),0x4e4f534a)+raw+struct.pack('<II',len(data),0x004e4942)+data)

def points(matrix, xyz):
    return np.asarray(xyz)@matrix[:3,:3].T+matrix[:3,3]

def components(xyz,faces):
    """Connect coincident corners, retaining the original indices and attributes."""
    epsilon=max(float(np.ptp(xyz,axis=0).max())*1e-6,1e-8)
    _,ids=np.unique(np.rint(xyz/epsilon).astype(np.int64),axis=0,return_inverse=True)
    parent=np.arange(ids.max()+1)
    def root(a):
        while parent[a]!=a:
            parent[a]=parent[parent[a]];a=parent[a]
        return a
    for a,b,c in ids[faces]:
        r=root(a);parent[root(b)]=r;parent[root(c)]=r
    labels=np.array([root(i) for i in ids[faces[:,0]]])
    return [np.flatnonzero(labels==i) for i in np.unique(labels)]

if __name__=='__main__':
    import sys
    for path in Path(sys.argv[1]).glob('*.glb'):
        g=GLB(path);world=g.worlds();print('\n',path.name)
        for i,n in enumerate(g.doc['nodes']):
            if any(s in n.get('name','').lower() for s in ['wheel','rin','tyres','body_sg','standard00']):
                if 'mesh' in n:
                    p=np.concatenate([points(world[i],g.array(p['attributes']['POSITION'])) for p in g.doc['meshes'][n['mesh']]['primitives']])
                    print(i,n.get('name'),np.round((p.min(0)+p.max(0))/2,3),np.round(np.ptp(p,axis=0),3))
                else: print(i,n.get('name'),np.round(world[i][:3,3],3))
