"""Collect verified results and provenance into the candidate evidence bundle."""
from pathlib import Path
import hashlib,json,shutil,subprocess
from candidate_232 import ROOT,BASE,QA,dump
OUT=ROOT/'docs/qa-vehicle232'

def marker(path,prefix):
    for line in path.read_text(encoding='utf-8',errors='replace').splitlines():
        if line.startswith(prefix):return json.loads(line[len(prefix):])
    raise AssertionError((path,prefix))

def sha(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    units=marker(QA/'features-final.log','VEHICLE_FEATURE_TEST ');assert units['status']=='PASS' and units['checks']==53
    cars=marker(QA/'all-48.log','VEHICLE_VALIDATION ')
    assert cars['status']=='PASS' and len(cars['vehicles'])==48 and sum(row['official'] for row in cars['vehicles'])==16
    dump(OUT/'all-48.json',cars);dump(OUT/'features-test.json',units)
    tests={}
    for name,prefix in [('existing-input','LOCAL_INPUT_TEST '),('existing-workshop','WORKSHOP_TEST '),('existing-presentation','LOCAL_PRESENTATION_TEST '),('existing-local-race','LOCAL_RACE_TEST ')]:
        tests[name]=marker(QA/(name+'.log'),prefix);assert tests[name]['status']=='PASS'
    assert 'VEHICLE_CODEC_PASS vehicles=16' in (QA/'existing-codec.log').read_text()
    for name in ['package-cameras-forward','package-cameras-compatibility']:
        report=json.loads((OUT/name/'camera-test.json').read_text());assert report['status']=='PASS' and report['checks']==69;tests[name]=report
    races=[]
    for track in ['astra_coast','colombo_city','kandy_lake']:
        for mode in ['single','split']:
            report=json.loads((QA/('race-'+track+'-'+mode)/(mode+'-'+track+'.json')).read_text());assert report['status']=='PASS';races.append(report)
    dump(OUT/'races.json',races);dump(OUT/'checks.json',tests)
    performance={}
    for version in ['2.3.1','2.3.2']:
        performance[version]={}
        for label,method in [('forward','forward_plus'),('compatibility','gl_compatibility')]:
            performance[version][label]=json.loads((QA/('performance-'+version+'-'+label)/('performance-'+method+'.json')).read_text())
    dump(OUT/'performance.json',performance)
    old=json.loads((ROOT/'build/Release-2.3.1/GameAssets/vehicles/bigster/vehicle.json').read_text())
    new=json.loads((BASE/'GameAssets/vehicles/bigster/vehicle.json').read_text())
    fields=['max_speed','boosted_speed','acceleration','handling','braking_regeneration','collision_position','collision_size','normalization','wheels','driver_fits','ai_lateral_acceleration']
    assert all(old.get(key)==new.get(key) for key in fields)
    tracks={}
    for name in ['astra_coast','colombo_city','kandy_lake']:
        old_folder=ROOT/'build/Release-2.3.1/GameAssets/tracks'/name;new_folder=BASE/'GameAssets/tracks'/name
        old_files={p.relative_to(old_folder).as_posix():sha(p) for p in old_folder.rglob('*') if p.is_file()}
        new_files={p.relative_to(new_folder).as_posix():sha(p) for p in new_folder.rglob('*') if p.is_file()}
        assert old_files==new_files;tracks[name]=old_files
    dump(OUT/'unchanged-driving-and-tracks.json',{'driving_fields':fields,'all_equal':True,'track_files':tracks})
    source_names=subprocess.check_output(['git','diff','--name-only'],cwd=ROOT,text=True).splitlines()
    source_names += [str(p.relative_to(ROOT)).replace('\\','/') for pattern in ['scripts/catalog/vehicle_features.gd','scripts/content/vehicle_feature*.gd','scripts/content/vehicle_check.gd','scripts/local/race_camera.gd','tools/*232*','tools/author_bigster_features.py','tests/vehicle_features*.gd','tests/vehicle_camera_test.gd','assets/models/bigster/bigster_232.glb','docs/VEHICLE_FEATURES.md'] for p in ROOT.glob(pattern)]
    dump(OUT/'source-fingerprints.json',{'base_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'working_tree':True,'files':{name:sha(ROOT/name) for name in sorted(set(source_names)) if (ROOT/name).is_file()}})
    for name in ['features-final','existing-input','existing-codec','existing-workshop','existing-presentation','existing-local-race','all-48','package-cameras-forward','package-cameras-compatibility']+[f'performance-{version}-{renderer}' for version in ['2.3.1','2.3.2'] for renderer in ['forward','compatibility']]+[f'race-{track}-{mode}' for track in ['astra_coast','colombo_city','kandy_lake'] for mode in ['single','split']]:
        shutil.copy2(QA/(name+'.log'),OUT/(name+'.log'))
    shutil.copy2(ROOT/'build/kandy231/bigster-light-states.log',OUT/'baseline-brake-state-investigation.log')
    shutil.copy2(ROOT/'build/kandy231/text.json',OUT/'text-audit.json')
    assert json.loads((OUT/'text-audit.json').read_text())['status']=='PASS'
    rows=[]
    for label in ['forward','compatibility']:
        a=performance['2.3.1'][label];b=performance['2.3.2'][label]
        rows.append(f"| {label} | {a['fps']:.1f} → {b['fps']:.1f} | {a['p95_ms']:.2f} → {b['p95_ms']:.2f} | {a['static_peak_mb']:.2f} → {b['static_peak_mb']:.2f} | {a['vram_peak_mb']:.1f} → {b['vram_peak_mb']:.1f} | {a['max_frame_ms']:.1f} → {b['max_frame_ms']:.1f} |")
    text='''# Leo Racer 2.3.2 — Windows test candidate

Implemented Bigster's automatic brake/reverse lamps, switchable headlights and
sliding sunroof; reusable vehicle feature metadata/Workshop authoring; two
assignable action slots; automatic reverse view, held Look Back and mouse/right-
stick orbit. The build contains the original 16 default cars and three tracks.
It is a local test candidate, not a new public GitHub release.

This revision includes Bigster 1.2.1: narrow red Y-shaped upper LED rails,
a separate white reversing lamp in the rear bumper, and illuminated main front
optical cells alongside the signature strips. See LIGHTING_CORRECTION.md and
the close views in lamps-forward/ and lamps-compatibility/. The prior package's
upper-cluster reverse bindings were incorrect and have been removed.

## Verified

- 53 focused feature checks: six actual physics light-state cases, independent
  cars/materials, roof reversal/recovery, embedded animation clips, malformed
  metadata, legacy profile support, controller profiles and mouse ownership.
  Added optical-group checks ensure the reverse target/anchor is in the bumper,
  both main headlamp cells and signatures illuminate, and only inset red Y rails
  emit in the upper rear clusters.
- 69 packaged camera/command checks in each renderer, across all three tracks
  in single-player and split-screen, including separated players and wall tests.
- Six Windows three-lap race checks: six racers, all three tracks,
  single-player and split-screen. All passed.
- Existing input (35), Workshop (22), presentation (21), local race (21) checks;
  codec round-trip for 16 cars. All passed.
- Installed-content validation: all 48 cars import, 16 remain official, optional
  imported cars remain unranked. No unavailable vehicles or missing wheels.
- Startup/loading punctuation audit passed. Bigster handling, wheels, collision,
  normalization and driver fits match 2.3.1. All track-package files match 2.3.1.
- Screenshots show independent brake/reverse/headlights, open/closed roofs, and
  reverse views in Forward+ and Compatibility. Raw logs and JSON are included.

## Observed performance

NVIDIA RTX A1000 6GB Laptop GPU; Kandy at 1920×1080, two separated local players,
six racers, 30-second measurement after warm-up. Each cell is 2.3.1 → 2.3.2.
These are local observations, not a controlled hardware benchmark.
The latest Forward+ run included a 146.6 ms maximum frame despite its 14.3 ms
p95; the candidate does not claim that streaming or frame-time spikes are solved.

| Renderer | FPS | p95 frame ms | Peak static MB | Peak VRAM MB | Maximum frame ms |
|---|---:|---:|---:|---:|---:|
'''+ '\n'.join(rows)+'''

Both versions emit Godot renderer/ObjectDB cleanup diagnostics at shutdown,
particularly Compatibility texture leaks; the repeated track-change camera
stress test also reports unreleased render resources at exit. Functional checks
passed and processes exited normally. These warnings are retained in the logs;
this candidate does not claim warning-free renderer teardown. Physical
controller/wheel hardware testing remains unverified; automated checks inject
device events and exercise ownership, rebinding and disconnection behavior.

## Use

Extract the complete portable ZIP into its own folder and run LeoRacer.exe.
L toggles headlights, O toggles Bigster's sunroof, C holds Look Back, and right-
mouse drag orbits. Gamepad defaults: D-pad left/up/down for lights/actions 1/2,
right-stick click for Look Back, right stick for orbit. Change them in Controls.
Bigster Action 2 is intentionally unassigned. The standalone Bigster package
requires core 2.3.2. Content → Vehicles → Set Up Vehicle edits other cars' rigs.

Original downloads, synced sources, the installed game, settings and records
were not edited. Diagnostic profiles live under build/vehicle232/profiles.
The source working tree and its base commit are recorded in source-fingerprints.
See VEHICLE_FEATURES.md beside this report for the authoring/API guide.
'''
    if (OUT/'extracted-package.json').exists():
        extracted=json.loads((OUT/'extracted-package.json').read_text());assert extracted['status']=='PASS'
        text+='\nThe portable ZIP was extracted and its member hashes checked against the build.\nContent, boot artwork and all 69 packaged camera/command assertions passed from\nthat extraction with .NET SDK paths removed and DOTNET_ROOT pointing to an empty\nlocation. The included Windows runtime is self-contained.\n'
    (OUT/'TEST_REPORT.md').write_text(text,encoding='utf-8')
    shutil.copy2(ROOT/'docs/VEHICLE_FEATURES.md',OUT/'VEHICLE_FEATURES.md')
    print('VEHICLE232_REPORT_READY',flush=True)

if __name__=='__main__':main()
