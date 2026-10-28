"""User-requested local playtest checkpoint; does not assert release acceptance."""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess, zipfile
import city_packs

R = Path(__file__).resolve().parents[1]
BASE = R / 'build/LightingCheckpoint'
CONTENT = R / 'build/lighting-content/GameAssets'
OUT = R / 'dist/lighting-checkpoint'

def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def dump(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')

def stage():
    assert (BASE / 'LeoRacer.exe').is_file(), 'Export into the independent checkpoint folder first'
    city_packs.split(BASE, True)
    assets = BASE / 'GameAssets'
    for name in ['vehicles', 'tracks', 'environments', 'licenses']:
        shutil.copytree(CONTENT / name, assets / name, dirs_exist_ok=True)
    catalog = json.loads((assets / 'catalog.json').read_text())
    catalog.update(vehicle_api=2, core={'min': '2.6.0', 'max_major': 2})
    neutral = assets / 'environments/dusk-neutral.pck'
    catalog['packs'].append({'id': 'environments/dusk-neutral', 'file': 'environments/dusk-neutral.pck',
                             'sha256': sha(neutral), 'bytes': neutral.stat().st_size})
    dump(assets / 'catalog.json', catalog)
    # Splitting rebuilds the baseline registry; restore the derivative track hashes.
    engine, entries = city_packs.read_pack(BASE / 'LeoRacer.pck')
    for name in ['official-tracks.json', 'official-track-content.json']:
        entries['assets/config/' + name] = (R / 'assets/config' / name).read_bytes()
    city_packs.write_pack(BASE / 'LeoRacer.pck', engine, entries)
    for pack in catalog['packs']:
        assert sha(assets / pack['file']) == pack['sha256'], pack['file']
    for path in (assets / 'tracks').glob('*/manifest.json'):
        data = json.loads(path.read_text())
        for pack in data['packs']:
            assert sha(path.parent / pack['file']) == pack['sha256'], str(path)
    assert len(list((assets / 'vehicles').glob('*/vehicle.json'))) == 21
    shutil.copy2(R / 'docs/LIGHTING_VALIDATION.md', BASE / 'TEST_REPORT.md')
    (BASE / 'README.txt').write_text(
        'LEO RACER - LIGHTING LOCAL PLAYTEST CHECKPOINT\n\n'
        'Run Play Lighting.cmd. Keep the complete extracted folder together.\n'
        'This launcher uses a separate local UserData folder for test saves.\n'
        'Use Play Compatibility.cmd to test OpenGL. No SDK installation required.\n'
        '21 cars, three tracks, Static and Dusk to Night lighting.\n'
        'The requested photo-reference garage redesign has NOT started in this checkpoint.\n'
        'This is a local playtest, not a performance-approved release. See TEST_REPORT.md.\n'
        'Extract into a NEW folder; do not merge into the existing installed game.\n'
        'Original source credits and licenses are retained under GameAssets/licenses and vehicles.\n', encoding='utf-8')
    for name, flags in [('Play Lighting.cmd', ''), ('Play Compatibility.cmd', '--rendering-method gl_compatibility --rendering-driver opengl3')]:
        (BASE / name).write_text('@echo off\ncd /d "%~dp0"\nset "APPDATA=%~dp0UserData"\nset "LOCALAPPDATA=%~dp0UserData"\nstart "" "LeoRacer.exe" ' + flags + '\n', encoding='ascii')
    print('LIGHTING_CHECKPOINT_STAGED', flush=True)

def smoke():
    import qa260
    qa260.Q = R / 'build/qa-lighting'
    reports = {}
    for compat in [False, True]:
        renderer = 'compatibility' if compat else 'forward'
        output = qa260.run('checkpoint-export-' + renderer, '', compat, extra=['--smoke-test'],
                           exe=BASE / 'LeoRacer.console.exe', vehicles=BASE / 'GameAssets/vehicles',
                           tracks=BASE / 'GameAssets/tracks')
        report = json.loads((BASE / 'smoke-test.json').read_text())
        assert report['status'] == 'PASS', report
        shutil.move(BASE / 'smoke-test.json', output / 'smoke-test.json')
        reports[renderer] = report
    dump(qa260.Q / 'checkpoint-export.json', {'status': 'PASS', 'core_sha256': sha(BASE / 'LeoRacer.pck'), 'renderers': reports})

def package():
    smoke_report = json.loads((R / 'build/qa-lighting/checkpoint-export.json').read_text())
    assert smoke_report['status'] == 'PASS' and smoke_report['core_sha256'] == sha(BASE / 'LeoRacer.pck')
    OUT.mkdir(parents=True, exist_ok=True)
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=R, text=True).strip()
    dump(BASE / 'checkpoint.json', {'branch': 'lighting', 'commit': commit, 'purpose': 'local playtest before garage redesign',
                                  'performance_acceptance': False, 'public_release': False, 'core_sha256': sha(BASE / 'LeoRacer.pck')})
    archive = OUT / 'LeoRacer-2.6.0-Lighting-Preview-win64.zip'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=4) as z:
        for path in sorted(BASE.rglob('*')):
            if path.is_file() and 'UserData' not in path.relative_to(BASE).parts:
                z.write(path, 'LeoRacer-Lighting/' + path.relative_to(BASE).as_posix())
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
    (OUT / 'SHA256SUMS.txt').write_text(sha(archive) + '  ' + archive.name + '\n', encoding='utf-8')
    print(str(archive), flush=True)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['stage', 'smoke', 'package'])
    globals()[parser.parse_args().action]()
