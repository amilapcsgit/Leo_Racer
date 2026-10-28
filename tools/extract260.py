"""Verify the delivered portable ZIP in a fresh, isolated game folder."""
from pathlib import Path
import json, os, zipfile
import release_260 as release
import verify_distinct as verify

root = release.ROOT / 'build/extracted260'
assert not root.exists(), 'Use a fresh extraction destination'
archive = release.OUT / 'LeoRacer-2.6.0-preview-win64.zip'
with zipfile.ZipFile(archive) as package:
    assert package.testzip() is None
    for entry in package.infolist():
        target = (root / entry.filename).resolve()
        assert target.is_relative_to(root.resolve()), entry.filename
    package.extractall(root)
base = root / 'LeoRacer'
vehicles = base / 'GameAssets/vehicles'
assert len(list(vehicles.glob('*/vehicle.json'))) == 21
assert len(list((base / 'GameAssets/tracks').glob('*/manifest.json'))) == 3
assert release.sha(base / 'LeoRacer.pck') == release.sha(release.BASE / 'LeoRacer.pck')
verify.QA = release.QA / 'zip-extraction'
os.environ['LEO_ASSET_ROOT'] = str(base / 'GameAssets')
ok = verify.run('clean-content', base, args=['--verify-content'], vehicles=vehicles, timeout=400)
release.dump(release.QA / 'zip-extraction.json', {
    'status': 'PASS' if ok else 'FAIL', 'zip_crc': 'PASS',
    'default_vehicles': 21, 'tracks': 3, 'sdk_removed': True,
    'core_sha256': release.sha(base / 'LeoRacer.pck'),
    'archive_sha256': release.sha(archive), 'isolated_folder': str(base),
})
assert ok
print('ZIP_EXTRACTION260_PASS', flush=True)
