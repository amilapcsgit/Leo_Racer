"""Consolidate the recorded Astra engine checks and verify delivery artifacts."""
from pathlib import Path
import hashlib, json, subprocess
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'docs/qa-astra'
errors, checks = [], []

def verify(condition, label):
    checks.append(label)
    if not condition: errors.append(label)
    print(('PASS ' if condition else 'FAIL ') + label)

def read(name):
    return json.loads((QA / name).read_text(encoding='utf-8-sig'))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def git(*args):
    return subprocess.check_output(['git', '-c', 'safe.directory='+ROOT.as_posix(), '-C', str(ROOT), *args])

for name in ['vehicles.json', 'route-runtime.json', 'playability.json', 'drive-test.json',
             'presentation-test.json', 'race-test.json', 'fleet-race.json', 'smoke-test.json',
             'ui-layout.json', 'windows-vulkan-smoke.json', 'windows-compatibility-smoke.json',
             'windows-vulkan-race.json']:
    report = read(name)
    verify(report.get('status') == 'PASS', name+' engine checks pass')

audit = read('model-audit.json')
for name, model in audit['models'].items():
    verify(sha(ROOT/model['glb']) == model['glb_sha256'], name+' matches the inspected Blender export')
    verify((ROOT/model['editable_source']).is_file(), name+' has editable Blender source')

baseline = 'f213a1d591c67b7fa54a1eee343d5e8e4a55fe41'
original = []
for item in git('ls-tree', '-r', '-z', baseline, 'assets/models').split(b'\0'):
    if not item: continue
    metadata, path = item.split(b'\t', 1)
    name = path.decode()
    if name.endswith('.glb'):
        expected = metadata.decode().split()[2]
        current = git('hash-object', '--', name).decode().strip()
        original.append((name, expected == current))
verify(all(ok for _, ok in original), 'All '+str(len(original))+' baseline GLBs remain byte-identical')

for path in (ROOT/'assets/art/astra').glob('*.png'):
    with Image.open(path) as image:
        verify(image.mode == 'RGBA' and image.getchannel('A').getextrema() == (0,255), path.name+' has transparent paint exterior')

profile = read('render-profile.json')
verify(profile['full_race_completed'] and profile['racer_count'] == 6, 'Real-renderer profile covers a complete six-racer race')
verify(profile['viewport_pixels'] == [1920,1080], 'Profile uses 1080p')
verify(profile['mean_fps'] >= 60 and profile['p95_frame_ms'] <= 18, '1080p performance target is met')

captures = json.loads((QA/'captures/capture-manifest.json').read_text())
verify(captures.get('errors',[]) == [], 'Capture tour has no save errors')
verify(len(captures['captures']) >= 34 and all(c['width'] == 1920 and c['height'] == 1080 for c in captures['captures']), 'Final capture tour has matching 1080p frames')

manifest = read('build-manifest.json')
archive = ROOT/'dist/LeoRacer-Windows-v1.4-Astra.zip'
verify(archive.is_file() and sha(archive) == manifest['zip_sha256'], 'Windows ZIP matches its delivery hash')
verify(manifest['runtime_bundled'] and manifest['terrain_library_bundled'], 'Windows package includes runtime and native extension libraries')
verify(git('branch','--show-current').decode().strip() == 'astra', 'Source is on astra')

report = {'status':'PASS' if not errors else 'FAIL','checks':len(checks),'errors':errors,
          'baseline_glbs_preserved':len(original), 'capture_count':len(captures['captures']),
          'performance':{k:profile[k] for k in ['device','viewport_pixels','mean_fps','p95_frame_ms','p99_frame_ms','minimum_one_second_fps','sample_wall_seconds','full_race_completed']},
          'zip_sha256':manifest['zip_sha256']}
(QA/'delivery-audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
raise SystemExit(1 if errors else 0)
