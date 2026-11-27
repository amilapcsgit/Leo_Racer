"""Stage verified released content on a clean runner; never reuse an old core."""
from pathlib import Path
import argparse, hashlib, json, shutil, urllib.request, zipfile
ROOT = Path(__file__).resolve().parents[1]
def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''): digest.update(block)
    return digest.hexdigest()
def stage(archive=None):
    lock=json.loads((ROOT/'content-baseline-lock.json').read_text())
    archive=Path(archive) if archive else ROOT/'build/downloads/LeoRacer-2.6.0-win64.zip'
    if not archive.exists():
        archive.parent.mkdir(parents=True,exist_ok=True)
        urllib.request.urlretrieve(lock['url'],archive)
    if sha(archive)!=lock['sha256']: raise RuntimeError('Content baseline checksum mismatch')
    target=ROOT/'build/content-baseline/GameAssets'
    target.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(archive) as bundle:
        for entry in bundle.infolist():
            if not entry.filename.startswith(lock['prefix']) or entry.is_dir():continue
            relative=Path(entry.filename.removeprefix(lock['prefix']))
            destination=(target/relative).resolve()
            if not destination.is_relative_to(target.resolve()):raise RuntimeError('Unsafe archive path')
            destination.parent.mkdir(parents=True,exist_ok=True)
            with bundle.open(entry) as source,destination.open('wb') as output:shutil.copyfileobj(source,output)
    catalog=json.loads((target/'catalog.json').read_text(encoding='utf-8-sig'))
    for pack in catalog['packs']:
        if sha(target/pack['file'])!=pack['sha256']:raise RuntimeError('Invalid content pack: '+pack['file'])
    vehicles=list((target/'vehicles').glob('*/vehicle.json'))
    for vehicle in vehicles:
        data=json.loads(vehicle.read_text(encoding='utf-8-sig'))
        if data.get('pack') and sha(vehicle.parent/data['pack'])!=data['pack_sha256']:raise RuntimeError('Invalid vehicle pack: '+vehicle.parent.name)
    tracks=list((target/'tracks').glob('*/manifest.json'))
    if len(vehicles)!=lock['vehicles'] or len(tracks)!=lock['tracks']:raise RuntimeError('Incomplete content catalog')
    print('ULTRA_CONTENT_READY',len(vehicles),'cars',len(tracks),'tracks',target,flush=True)
    return target
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--archive');args=parser.parse_args();stage(args.archive)
