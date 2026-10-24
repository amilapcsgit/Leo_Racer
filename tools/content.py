"""Independent data-content builds. Never exports an executable for vehicle/track targets."""
from pathlib import Path
import argparse, hashlib, json, shutil, struct, zipfile

ROOT = Path(__file__).resolve().parents[1]
DEV = ('bigster', 'duster')

def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))

def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def model_document(path):
    with Path(path).open('rb') as stream:
        head = stream.read(20)
        assert len(head) == 20 and head[:4] == b'glTF', 'Not a binary glTF model'
        magic, version, total, length, kind = struct.unpack('<5I', head)
        assert version == 2 and kind == 0x4e4f534a and total == Path(path).stat().st_size
        assert length <= total-20
        data = json.loads(stream.read(length))
    for image in data.get('images', []):
        assert not image.get('uri') or image['uri'].startswith('data:'), 'Embed model textures before distribution'
    assert all(not b.get('uri') for b in data.get('buffers', [])), 'GLB must contain its geometry'
    return data

def vehicle(key, destination):
    sources = read(ROOT/'content/vehicle-sources.json')
    assert key in sources, 'Unknown source vehicle: '+key
    source = sources[key]
    folder = Path(destination)/key
    folder.mkdir(parents=True, exist_ok=True)
    model = ROOT/source['model'].removeprefix('res://')
    model_document(model)
    shutil.copy2(model, folder/'model.glb')
    shutil.copy2(ROOT/'content/vehicles'/key/'vehicle.json', folder/'vehicle.json')
    if source.get('thumbnail'):
        shutil.copy2(ROOT/source['thumbnail'].removeprefix('res://'), folder/'thumbnail.png')
    (folder/'LICENSE.txt').write_text('Original Leo Racer vehicle, retained from v2.1.0.\n'
        'Original third-party notices and provenance are retained in GameAssets/licenses/.\n'
        'This file does not replace or expand those licenses.\n', encoding='utf-8')
    return folder

def registry():
    result = {}
    for key, source in read(ROOT/'content/vehicle-sources.json').items():
        result[key] = {'definition': sha(ROOT/'content/vehicles'/key/'vehicle.json'),
                       'model': sha(ROOT/source['model'].removeprefix('res://'))}
    (ROOT/'assets/config/official-vehicles.json').write_text(json.dumps(result, indent=2)+'\n')
    return result

def archive(folder, kind, content_id, destination):
    destination = Path(destination);destination.mkdir(parents=True, exist_ok=True)
    result = destination/f'LeoRacer-{kind}-{content_id}.zip'
    with zipfile.ZipFile(result, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for p in sorted(Path(folder).rglob('*')):
            if p.is_file():z.write(p, 'GameAssets/'+kind+'/'+content_id+'/'+p.relative_to(folder).as_posix())
    result.with_suffix('.sha256').write_text(sha(result)+'  '+result.name+'\n')
    return result

def main():
    parser=argparse.ArgumentParser()
    sub=parser.add_subparsers(dest='target',required=True)
    p=sub.add_parser('registry')
    p=sub.add_parser('stage');p.add_argument('--profile',choices=['dev','full'],default='dev');p.add_argument('--output',type=Path,default=ROOT/'build/Modularity/GameAssets')
    p=sub.add_parser('vehicle');p.add_argument('id');p.add_argument('--output',type=Path,default=ROOT/'build/content-vehicles');p.add_argument('--zip',action='store_true')
    args=parser.parse_args()
    if args.target=='registry':print('OFFICIAL_VEHICLES',len(registry()));return
    if args.target=='stage':
        keys=DEV if args.profile=='dev' else read(ROOT/'content/vehicle-sources.json').keys()
        for key in keys:vehicle(key,args.output/'vehicles')
        print(json.dumps({'status':'PASS','profile':args.profile,'vehicles':list(keys),'core_export_invoked':False}))
    elif args.target=='vehicle':
        folder=vehicle(args.id,args.output)
        result=archive(folder,'vehicles',args.id,ROOT/'dist/content') if args.zip else folder
        print('VEHICLE_BUILT',args.id,result.name,'core_export_invoked=false')

if __name__=='__main__':main()
