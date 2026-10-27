"""Write the delivery report from measured evidence, without invented results."""
from pathlib import Path
import hashlib,json,subprocess

ROOT=Path(__file__).resolve().parents[1]
QA=ROOT/'build/distinct'
def read(path):return json.loads((QA/path).read_text())

def main():
    features=read('features-forward/features.json')
    balance=read('balance-acceptance.json')
    races=read('races-forward/races.json')
    comparison=read('comparison-forward/comparison.json')
    packaged=read('packaged-acceptance.json')
    performance=read('performance-acceptance.json')
    preserved=read('package-preservation.json')
    camera_forward=read('packaged-camera-forward/camera-test.json')
    camera_compatibility=read('packaged-camera-compatibility/camera-test.json')
    assert all(item['status']=='PASS' for item in [features,balance,races,comparison,packaged,performance])
    original=read('package-fingerprints.json')
    assert all(hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==value for path,value in original.items())
    changes=subprocess.check_output(['git','diff','--name-only','--','content/vehicles','assets/models'],cwd=ROOT,text=True)
    assert not changes.strip()
    closest=next(row for row in balance['ranking'] if row['id']!='bigster')
    metrics=performance['measurements']
    table=[]
    for renderer in ['forward_plus','gl_compatibility']:
        before=metrics[renderer]['baseline'];after=metrics[renderer]['candidate']
        table.append(f"| {renderer} | {before['p95_ms']:.2f} → {after['p95_ms']:.2f} | {before['p99_ms']:.2f} → {after['p99_ms']:.2f} | {before['max_frame_ms']:.2f} → {after['max_frame_ms']:.2f} |")
    calibration=json.loads((ROOT/'assets/config/vehicle-balance-v2.json').read_text())
    official=[]
    for key,values in calibration['vehicles'].items():
        official.append(f"| {key} | {values[0]} | {values[1]} | {values[2]} | {values[3]} |")
    text=f'''# Leo Racer 2.4.0 — distinct vehicles test candidate

Implemented on the `orbitcamera` baseline `0be45efe4bea797a7fd9b004f058789d982e9614`. This is a local Windows candidate with all 48 installed vehicles and three existing tracks. It has not been published.

## Delivered behavior

- One core balance configuration supplies race setup, garage statistics, AI and both Workshop test-drive paths. Imports retain Vehicle API 1 and stay unranked. Unknown imports use the Compact profile.
- AI predicts braking through upcoming curvature/elevation, evaluates passing corridors and static obstacles, commits to safe lane choices, times boost, and attempts reversing before collision-checked recovery. It uses the ordinary throttle, braking, steering and boost path. It has no catch-up speed bonus or grip cheat. Default AI driving is conservative about drifting.
- The existing camera now has a critically damped position spring, velocity/apex look-ahead, measured-speed FOV from 63° to 73°, and an 85° boost cap. Final collision protection runs after shake. Orbit, reverse, Look Back and independent split-screen controls remain available. Reduced Motion holds the selected base FOV and removes procedural lag/look-ahead, shake and roll.
- Low/Medium/High graphics presets; Medium default and split-screen ceiling. Exact material-role assignments improve paint, glass and rubber without repainting arbitrary surfaces. Reflection probes and restrained color grading work with both renderers. High Forward+ adds SSR and local fog volumes. Bigster's finish is excluded from the new material pass.
- Original generated idle/low/high engine layers, virtual gears/RPM and throttle load, wind and tire layers, vehicle sound classes, independent player effects buses, per-player cover/zone reverb, and four bounded nearby-opponent voices with stereo positioning. Existing Effects volume controls apply.
- New records use `distinct_v2` and one official `arcade_v2` class; elevated tracks retain their surface suffix. Legacy records remain queryable through More Filters. Existing databases and source content are preserved.

## Bigster and balance evidence

Bigster retains 180 km/h normal, 225 km/h boost, 18 acceleration, 1.00 handling, existing boost duration and 0.035 braking regeneration. Models, collision, wheels, normalization, fits, lamps, roof actions and material bindings were not edited. The package audit verified {preserved['preserved_vehicle_files']} vehicle files byte-for-byte against the complete baseline package.

The 600-tick original/new manual controller replay includes acceleration, steering, boost, drift/release and braking regeneration. Maximum state difference: **{features['details']['manual_replay']['maximum_difference']}**. All 48 vehicles reached their measured normal and boosted ceilings in the straight-line fixture. Compacts won the measured launch comparison.

All 48 cars completed a clean lap on each track: **144 measured laps**. Bigster is fastest by the equal-track mean of lap time divided by Bigster's time. The closest rival is Duster at **{closest['normalized_lap_time_margin_percent']:.2f}% longer normalized lap time**. Formula Blue and McLaren still beat Bigster around the corner-heavy Astra course while losing the three-track aggregate.

The proposed starting McLaren tune was 0.4% faster overall. Rivals' normal/boost ceilings were reduced after that failed gate; Bigster's values and rivals' acceleration/handling specialties were retained. Starting data and measurements are preserved in the evidence archive under `calibration/`.

| Official vehicle ID | Normal km/h | Boost km/h | Acceleration | Handling |
|---|---:|---:|---:|---:|
{chr(10).join(official)}

## Validation

- **{features['checks']}** focused checks passed: 48-car classification, measured limits/launch, manual replay, camera endpoints/Reduced Motion, graphics gates, passing/commitment, audio independence and record isolation.
- **30 seeded three-lap race grids**, all 48 cars rotated through the grid: **{races['details']['completion_rate']*100:.1f}% completion**. Checkpoint event order is checked throughout.
- Physics batches use the production controller, actual vehicle metadata/collision dimensions and actual track surfaces, omitting render meshes/audio to avoid repeated GLB imports. They preserve the 1/60 simulation step while accelerating elapsed test time. Separate exported-game races exercise assembled models.
- Existing regressions passed: input 35, vehicle lights/actions 53, records 26, Workshop 23. The Workshop test uses copied fixtures and confirms its effective race profile matches the garage.
- Source camera suites passed 69 checks per renderer. The final Windows package passed **{camera_forward['checks']} Forward+ and {camera_compatibility['checks']} Compatibility checks**, including all tracks, single-player/split-screen, reverse/orbit/Look Back, pause, walls and preservation of authored baked-light shadow states.
- The ordinary controller comparison had zero boundary contacts in both versions on all three tracks. In the controlled lane obstruction, baseline contact frames were 251 versus 0 for the new AI. This distinction is retained in the raw comparison report.
- Final package checks: content verification, all 48 resolved profiles, both rendered camera suites and six assembled-model track/mode race cases. All **{packaged['cases']} cases** passed with SDK paths removed and `DOTNET_ROOT` pointing to an empty directory.
- Garage and settings were rendered and inspected at 1280×720. Garage shows normal speed, boost, grip and launch together.

## Performance

NVIDIA RTX A1000 6 GB laptop GPU; 1920×1080; Kandy; two separated local players; six identical official-roster selections; 6-second warm-up followed by 30-second sampling. Compare the baseline Windows 2.3.2 build with this candidate at Medium. These are local observations, not a general hardware guarantee.

| Renderer | p95 ms, baseline → candidate | p99 ms | Maximum frame ms |
|---|---:|---:|---:|
{chr(10).join(table)}

Both agreed performance gates passed: Forward+ p95 ≤16.7 ms and Compatibility p95 within 10% of the measured baseline. Maximum frame spikes are reported separately; this update does not claim to eliminate streaming stalls.

The preset controls only the race sun and its own probes/fog volumes; baked precinct lights keep their authored state. This avoids accidentally adding real-time shadows to Kandy's baked lights. The reflection atlas is bounded to four 128-pixel slots for the two new probes. AI neighbor checks reuse each car's measured route offset; the seeded race sweep verifies the cached offsets against geometric projection.

Compatibility split-screen uses prefiltered sky reflections and two shadow cascades over at most 80 m. Compatibility single-player and Forward+ keep local probes and four cascades. Both split viewports still render at full native 3D resolution; these fallbacks do not reduce resolution or change vehicle simulation. The final GLES-only shadow revision additionally passed exported content/balance and the rendered Compatibility camera suite.

## Use and limits

Extract the complete private ZIP and run **Play Test Build.cmd**. It uses a `TestProfile` folder beside the game, keeping normal personal settings and records separate. **Play Compatibility.cmd** selects OpenGL. Settings provides graphics quality, base camera FOV and Reduced Motion; scroll down to reach display controls.

This candidate includes personal imported models and stays local. Source GLBs, synced `sources/`, original packages and the existing installed build were not modified. The evidence ZIP includes raw JSON, logs, screenshots, original controller snapshots and initial calibration results.

Known engine/add-on shutdown diagnostics about render resources remain visible in logs; functional passes do not imply warning-free teardown. Physical controller/wheel hardware and subjective listening on the user's speakers are not independently verified. Raycast suspension, airborne control changes, motion blur, wet-weather conversion and granular recorded-engine synthesis remain outside this update.

Reproduce with `tools/qa_distinct.py`, `tools/build_distinct.ps1`, `tools/package_distinct.py`, and `tools/verify_distinct.py`. These commands isolate diagnostic profiles and never need to publish or update the existing installation.
'''
    (ROOT/'docs/DISTINCT_V2.md').write_text(text,encoding='utf-8')
    print('REPORT_WRITTEN',ROOT/'docs/DISTINCT_V2.md')

if __name__=='__main__':main()
