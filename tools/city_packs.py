"""Split a Godot export into lossless, deduplicated external category packs.

Reads Godot's documented-in-source PCK v2/v3/v4 directory; writes plain v3 packs.
Compiled resources and dependency remaps are preserved byte for byte.
"""
from __future__ import annotations
from pathlib import Path
import argparse, collections, hashlib, json, re, struct

ROOT=Path(__file__).resolve().parents[1]
def read_pack(path):
    blob=path.read_bytes()
    magic,version,major,minor,patch,flags=struct.unpack_from('<6I',blob)
    assert magic==0x43504447 and version in (2,3,4) and not flags&1,'Unsupported/encrypted PCK'
    base=struct.unpack_from('<Q',blob,24)[0]
    pos=struct.unpack_from('<Q',blob,32)[0] if version>=3 else 96
    count=struct.unpack_from('<I',blob,pos)[0];pos+=4;entries={}
    for _ in range(count):
        n=struct.unpack_from('<I',blob,pos)[0];pos+=4
        name=blob[pos:pos+n].rstrip(b'\0').decode();pos+=n
        off,size=struct.unpack_from('<QQ',blob,pos);pos+=16
        md5=blob[pos:pos+16];pos+=16
        file_flags=struct.unpack_from('<I',blob,pos)[0];pos+=4
        assert not file_flags,'Encrypted/delta entries are not supported'
        data=blob[base+off:base+off+size]
        assert len(data)==size and hashlib.md5(data).digest()==md5,name
        entries[name.removeprefix('res://')]=data
    return (major,minor,patch),entries

def write_pack(path,engine,entries):
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open('wb') as f:
        f.write(struct.pack('<6IQQ',0x43504447,3,*engine,2,128,0)+b'\0'*64)
        f.write(b'\0'*(128-f.tell()));directory=[];seen={}
        for name,data in sorted(entries.items()):
            digest=hashlib.md5(data).digest();key=(digest,len(data))
            if key not in seen:
                seen[key]=f.tell()-128;f.write(data);f.write(b'\0'*(-f.tell()%32))
            directory.append((name,seen[key],len(data),digest))
        offset=f.tell();f.write(struct.pack('<I',len(directory)))
        for name,pos,size,digest in directory:
            encoded=name.encode();encoded+=b'\0'*(-len(encoded)%4)
            f.write(struct.pack('<I',len(encoded))+encoded+struct.pack('<QQ',pos,size)+digest+struct.pack('<I',0))
        f.seek(32);f.write(struct.pack('<Q',offset))
    # An independent read verifies all offsets and hashes before delivery.
    assert read_pack(path)[1]==entries

def category(name):
    if name.startswith('assets/tracks/colombo_city/'):return 'tracks/colombo_city/scenery'
    if name.startswith('assets/tracks/astra_coast/') or name=='assets/track-astra.json':return 'tracks/astra_coast/scenery'
    if name.startswith('assets/models/colombo_city/'):return 'glb/colombo-buildings'
    if name.startswith(('assets/models/bigster/','assets/models/modular/','assets/models/cabin/','assets/models/astra/','assets/catalog/')):return 'vehicles/roster'
    if name.startswith('assets/materials/'):return 'textures/surfaces'
    if name.startswith('assets/signs/'):return 'signs/colombo'
    if name.startswith('assets/models/'):return 'glb/shared-scenery'
    if name.startswith('assets/terrain/'):return 'roads/terrain'
    if name.startswith('assets/art/'):return 'textures/art'
    if name.startswith('assets/audio/'):return 'audio/shared'
    return 'core'

def split(folder):
    source=folder/'LeoRacer.pck'
    previous=folder/'asset-sizes.json'
    if previous.exists() and source.stat().st_size==json.loads(previous.read_text())['core_bytes']:
        raise ValueError('Package already split: export the complete PCK before splitting again')
    engine,entries=read_pack(source)
    # Both playable tracks use regular baked/procedural meshes. Keep the old
    # Terrain3D tool installed in the editor, without an unused runtime DLL.
    if '.godot/extension_list.cfg' in entries:
        entries['.godot/extension_list.cfg']=b'\n'.join(line for line in entries['.godot/extension_list.cfg'].splitlines() if b'addons/terrain_3d/' not in line)
    owners={}
    for name,data in entries.items():
        if not name.endswith(('.import','.remap')):continue
        owner=category(name.removesuffix('.import').removesuffix('.remap'))
        for target in re.findall(r'res://[^"\s]+',data.decode(errors='ignore')):
            if target.startswith('res://.godot/'):owners[target[6:]]=owner
    groups=collections.defaultdict(dict)
    for name,data in entries.items():
        owner=owners.get(name,category(name))
        # Embedded and extracted copies of textures share a single pack/cache.
        if name.endswith('.ctex'):owner='textures/imported'
        # The bootstrap icon can be requested by the engine before content mounts.
        if 'leo_road_crest.png' in name:owner='core'
        groups[owner][name]=data
    root=folder/'GameAssets';packs=[];track_packs={}
    for group,files in sorted(groups.items()):
        target=source if group=='core' else root/(group+'.pck')
        write_pack(target,engine,files)
        if group!='core':
            entry={'id':group,'file':target.relative_to(root).as_posix(),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'bytes':target.stat().st_size}
            packs.append(entry)
            if group.startswith('tracks/'):track_packs[group.split('/')[1]]=entry
    for category_name in ['textures','vehicles','roads','signs','glb','tracks/astra_coast','tracks/colombo_city','licenses']:
        (root/category_name).mkdir(parents=True,exist_ok=True)
    names={name.removesuffix('.import').removesuffix('.remap') for name in entries if name.startswith('assets/')}
    assets={f'res://{name}':f'res://{name}' for name in sorted(names)}
    catalog={'format':1,'engine':'4.7','packs':[p for p in packs if not p['id'].startswith('tracks/')],'assets':assets,'overrides':[]}
    (root/'catalog.json').write_text(json.dumps(catalog,indent=2)+'\n',encoding='utf-8')
    for track in (ROOT/'assets/tracks').glob('*'):
        if not track.is_dir():continue
        import shutil
        for name in ['route.json','cells.json','preview.png']:
            if (track/name).exists():shutil.copy2(track/name,root/'tracks'/track.name/name)
        metadata=json.loads((track/'manifest.json').read_text(encoding='utf-8'))
        required=['vehicles/roster','glb/shared-scenery','textures/imported']
        required+=['glb/colombo-buildings','signs/colombo'] if metadata.get('world_kind')=='city' else ['roads/terrain','textures/surfaces','textures/art']
        metadata['dependencies']=[p['id'] for p in packs if p['id'] in required]
        if track.name in track_packs:
            pack=track_packs[track.name]
            metadata['packs']=[{'file':'scenery.pck','sha256':pack['sha256']}]
        (root/'tracks'/track.name/'manifest.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
    import shutil
    shutil.copytree(ROOT/'licenses',root/'licenses',dirs_exist_ok=True)
    (root/'README.txt').write_text('Optimized game content. Install complete compatible track folders under tracks/.\nRegistered cosmetic GLB/PNG/SVG overrides are listed in catalog.json overrides.\nEach override has id (resource path), file (relative GameAssets path), affects_rules (boolean).\nRoute/handling modifications cannot set official records. Keep settings and rankings in user data.\n',encoding='utf-8')
    report={'exe_bytes':(folder/'LeoRacer.exe').stat().st_size,'core_bytes':source.stat().st_size,'packs':packs,
            'installed_bytes':sum(p.stat().st_size for p in folder.rglob('*') if p.is_file()),
            'original_pack_bytes':sum(len(v) for v in entries.values()),'resources':len(entries)}
    (folder/'asset-sizes.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='packs'},indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('folder',type=Path);args=parser.parse_args();split(args.folder.resolve())
