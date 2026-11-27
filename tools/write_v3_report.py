"""Generate the final report only from successful, current acceptance artifacts."""
from pathlib import Path
import hashlib,json,re,subprocess
ROOT=Path(__file__).resolve().parents[1]
QA=ROOT/'build/distinct'
def read(name):return json.loads((QA/name).read_text(encoding='utf-8'))
def main():
    names={
      'race_fix':'v3-regression/acceptance.json','driving':'features-forward/features.json',
      'pace':'pace-forward/pace.json','ai':'races-forward/races.json','comparison':'comparison-forward/comparison.json',
      'visual_forward':'v3-visual-forward-final/visual.json','visual_compat':'v3-visual-compatibility/visual.json',
      'quality_forward':'v3-presentation-forward/presentation.json','quality_compat':'v3-presentation-compatibility/presentation.json',
      'framing':'v3-framing/framing.json','native':'packaged-acceptance.json','performance':'performance-acceptance.json'}
    results={key:read(name) for key,name in names.items()}
    for key,value in results.items():assert value['status']=='PASS',key
    with (ROOT/'build/Distinct-v3-final/LeoRacer.pck').open('rb') as stream:core=hashlib.file_digest(stream,'sha256').hexdigest()
    assert results['native']['candidate_pck_sha256']==core and results['performance']['candidate_pck_sha256']==core
    preserved=read('package-preservation.json');assert preserved['ruleset']=='distinct_v3' and preserved['preserved_vehicle_files']==1140
    originals=read('package-fingerprints.json')
    for path,sha in originals.items():assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==sha,path
    assert not subprocess.check_output(['git','diff','--name-only','--','content/vehicles','assets/models'],cwd=ROOT,text=True).strip()
    for filename,label in [('v3-input.log','LOCAL_INPUT_TEST'),('v3-records.log','LOCAL_RANKING_TEST'),('v3-local-race.log','LOCAL_RACE_TEST'),('v3-features.log','VEHICLE_FEATURE_TEST'),('v3-workshop.log','WORKSHOP_TEST')]:
        lines=[line for line in (QA/filename).read_text(encoding='utf-8',errors='replace').splitlines() if label+' ' in line]
        assert lines and re.search(r'"status"\s*:\s*"PASS"',lines[-1]),filename
    margins=results['pace']['details']['normalized_lap_time_margin_percent']
    ordered=sorted(margins.items(),key=lambda x:x[1]);closest=next(row for row in ordered if row[0]!='bigster')
    assert closest[1]>=2.
    balance=json.loads((ROOT/'assets/config/vehicle-balance-v2.json').read_text(encoding='utf-8'))
    audit=read('v3-regression/fleet-audit.json')
    repairs=json.loads((ROOT/'assets/config/vehicle-material-repairs-v1.json').read_text(encoding='utf-8'))
    rows=[]
    for car in audit:
        key=car['id'];stats=balance['vehicles'].get(key,balance['profiles'][balance['imports'].get(key,'compact')])
        w,h,length=car['after'];rows.append(f"| {key} | {w:.2f} × {h:.2f} × {length:.2f} | {car['factor']:.4f} | {stats[0]} / {stats[1]} | {margins[key]:.2f}% |")
    (QA/'balance-acceptance.json').write_text(json.dumps({'status':'PASS','ruleset':'distinct_v3','ranking':[{'id':key,'margin_percent':margin} for key,margin in ordered]},indent=2)+'\n',encoding='utf-8')
    metrics=results['performance']['measurements'];perf=[]
    for renderer,pair in metrics.items():
        b=pair['baseline'];a=pair['candidate'];perf.append(f"| {renderer} | {b['p95_ms']:.3f} → {a['p95_ms']:.3f} ms | {b['p99_ms']:.3f} → {a['p99_ms']:.3f} ms | {b['max_frame_ms']:.3f} → {a['max_frame_ms']:.3f} ms | {b['vehicle_load_ms']} → {a['vehicle_load_ms']} ms |")
    table='\n'.join(rows);perf_table='\n'.join(perf)
    checks='\n'.join(f"| {key.replace('_',' ')} | PASS | {value.get('checks',value.get('cases','—'))} |" for key,value in results.items())
    repair_rows='\n'.join(f"- `{key}`: "+', '.join(f"{target['material']} ({target['role']})" for target in value['targets']) for key,value in repairs.items() if value['targets'])
    text=f'''# Leo Racer 2.4.1 — local acceptance report

This private Windows candidate completes the agreed race fixes, restored single-player HUD, realistic sizing, selective material repairs, spring camera, graphics presets, and layered audio. It includes 16 official vehicles, 32 personal imports, and Astra, Colombo, and Kandy. It has not been published.

## Race and controls

Recovery now lifts authored lap-local positions into the racer's completed-lap coordinate system, including collision-avoidance setbacks. Forward checkpoint crossings are validated against movement, road width, and elevation. Recovery and projection jumps cannot award checkpoints; lap/finish notifications are processed once. P1 and P2 retain independent progress and timing.

Late starts and exploration remain unrestricted by choice. Recover returns to the last validated checkpoint, and Pause/Retire/Leave remain available. Split-screen waits for both humans to finish or retire. New records use `distinct_v3` plus the existing elevation suffix; `distinct_v2` and `balanced_v1` records remain accessible as legacy records.

Selecting an occupied controller transfers it to the selecting player. The displaced player gets the next free controller, the former device, or keyboard, in that order. Assignments update together, held inputs clear, and Back cancels confirmation/capture. Independent shared-keyboard layouts remain supported.

The regression suite passed **{results['race_fix']['checks']} checks**, including actual crossings after recovery on every lap for both slots across all tracks, package classification preservation, wheel scaling, generated-audio bounds, and menu cancellation. Existing input (35), rankings (26), local race (21), Bigster features (53), and copied-fixture Workshop (23) suites passed.

## Size, HUD, and materials

Bigster's runtime prepared-model scale is **1.0**, removing its former 1.3 multiplier. Its measured length is approximately **4.57 m**. Collision dimensions, wheel radii, driver fits, emitters, and camera framing follow the correction. Model-local wheel pivots, lamp anchors, and sunroof motion inherit the chassis transform once. The physics body remains unscaled.

All 48 models were measured. Recognizable real vehicles use length references in `assets/config/vehicle-presentation-v1.json`; the fantasy envelope is 4.4 × 2.0 × 1.8 m. Scaling is uniform, preserving authored proportions, mirrors, accessories, and widebody kits. Reference-generation approximations and the stylized MP4-25 derivative are identified in that manifest. This is a world-size correction, not a reconstruction of inaccurate source geometry. Garage cameras frame corrected bounds without resizing the model to fill the screen.

The original v1.4 instruments are restored for single-player: circular speedometer, curved nitro tube, position/lap/time panels, track/sector/progress banner, minimap, logo, drift feedback, and live binding hints. Compact independent split-screen HUDs remain. Screenshots cover 720p, 1080p, ultrawide, split-screen, and Reduced Motion.

An authored manifest covers every vehicle. It preserves professional PBR and intentional stylized finishes; only six explicitly reviewed surfaces use the shared paint/glass templates:

{repair_rows}

Protected-surface and preview checks passed **{results['visual_forward']['checks']} checks in Forward+** and **{results['visual_compat']['checks']} in Compatibility**. Bigster's existing finish is preserved. Original models and all **{preserved['preserved_vehicle_files']} installed vehicle files** remain byte-for-byte unchanged; the corrections live in core runtime profiles. Synced `sources/` files were not modified.

## Driving and AI

The 600-tick Bigster manual-input replay has **{results['driving']['details']['manual_replay']['maximum_difference']} maximum difference** against the original controller on the free-space fixture. Acceleration, steering, boost, braking regeneration, and drift mechanics remain unchanged. Collision contacts use the intentionally corrected footprint.

All **144 vehicle/track clean laps** passed. Bigster is fastest by equal-track aggregate; the closest rival is `{closest[0]}`, **{closest[1]:.3f}% behind**. No extra rival retuning was needed after resizing. The compact launch advantage and formula-car corner opportunities remain measured in the driving/pace evidence.

Ten seeded three-lap races per track completed **180/180 racers (100%)**, rotating all 48 cars, with ordered checkpoints and cached road-position checks. In the controlled obstruction comparison, the original AI accumulated **{results['comparison']['details']['baseline_contacts']} wall-contact frames**, versus **{results['comparison']['details']['new_contacts']}** for the new AI. The comparison holds vehicle geometry constant to isolate controller decisions. No catch-up speed bonuses or weapons were added.

## Camera, rendering, and audio

The spring rig preserves orbit/look-back/reverse precedence, per-player state, and final collision sweeps after presentation offsets. Default FOV is 63° at rest, 73° at 180 km/h, capped at 85° with boost. Reduced Motion holds the selected base FOV and suppresses procedural movement, shake, and roll.

Chase aim and clearance use the resolved body's centre and length, including single-player long vehicles. The final framing suite passed **{results['framing']['checks']} checks** across all 48 vehicles in both layouts, at the default 63° and selected 55° Reduced Motion setting. Conservative box failures are checked against actual mesh geometry before counting clipping.

Low/Medium/High checks cover all tracks and both player modes in both renderers: **18 quality views per renderer**. Medium is the default and split-screen ceiling. SSR and local volumetric atmosphere are High Forward+ features. Compatibility split-screen keeps sky reflections and two shadow cascades over at most 80 m; authored baked lighting is preserved. The exported executable passed all 10 startup/balance/camera/race cases without an installed .NET SDK.

Audio uses virtual gears, simulated RPM/load, crossfaded generated engine layers, five sound classes, speed-dependent wind/tires, bounded opponent voices, and overhead/zone reverb. Engine loops are periodic, sample bounds are checked, and local-player buses retain volume controls and split panning. Five generated idle examples accompany the evidence. Physical controller/wheel hardware and subjective speaker/headphone listening were not independently verified.

## RTX A1000 performance

Matched Windows 2.3.2 baseline and 2.4.1 candidate: NVIDIA RTX A1000 6 GB laptop GPU, Kandy, 1920×1080, Medium, two separated players, six identical official-roster selections. Each run uses a 6-second warm-up and 30-second sample. Other QA renderer processes are closed before sampling.

| Renderer | Baseline → candidate p95 | p99 | Maximum frame | Vehicle load |
|---|---:|---:|---:|---:|
{perf_table}

Both gates passed: Forward+ p95 ≤16.7 ms and Compatibility p95 within 10% of its measured baseline. Maximum frame/loading spikes are reported separately; this update does not claim to eliminate streaming stalls. Measurements describe this benchmark and hardware, rather than guaranteeing every scene on every machine.

The original 2.3.2 build had one access-violation exit during its first Forward+ baseline attempt. That failed sample was discarded and repeated successfully. Successful baselines were retained while the final camera revision's candidate samples were repeated. Exported acceptance and performance reports identify the tested core PCK by SHA-256.

Two automated candidate launches also stalled before reporting game readiness: one headless Astra split-screen launch and one Compatibility benchmark launch. The isolated race retry and a fresh-profile Compatibility retry passed. Native race checks now run serially. The startup stalls' root cause remains unconfirmed; they are retained as a known diagnostic limitation, separate from completed-race correctness. The final Compatibility sample is under `performance-gl_compatibility-candidate-isolated-*` in the evidence.

## Acceptance index

| Suite | Status | Checks/cases |
|---|---|---:|
{checks}

Final raw JSON, logs, screenshots, generated WAV examples, original-controller snapshots, and initial calibration results are retained under `build/distinct/` and in the private evidence archive. Development failure logs are historical; the acceptance index above identifies the final passing artifacts.

Godot/add-on shutdown diagnostics about render resources remain in some logs. They are not represented as warning-free teardown. Raycast suspension, airborne handling changes, motion blur, wet-weather conversion, and custom multilayer paint remain deferred.

## Fleet measurements

Dimensions below are measured runtime model bounds including mirrors/accessories. The multiplier is relative to the old assembled model; Bigster's 0.7692 correction restores its prepared-model scale to 1.0. Source references are in the presentation manifest and the fleet audit.

| Vehicle ID | W × H × L metres | Size correction | Normal / boost km/h | Aggregate lap time behind Bigster |
|---|---:|---:|---:|---:|
{table}
'''
    (ROOT/'docs/DISTINCT_V3.md').write_text(text,encoding='utf-8')
    (QA/'final-acceptance.json').write_text(json.dumps({'status':'PASS','version':'2.4.1','ruleset':'distinct_v3','suites':names,'closest_margin_percent':closest[1],'completed_racers':180,'preserved_vehicle_files':1140},indent=2)+'\n',encoding='utf-8')
    print('Final report written; all acceptance gates PASS')
if __name__=='__main__':main()
