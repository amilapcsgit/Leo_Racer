"""Write a measured candidate report; frame-time misses remain explicit."""
import json
from pathlib import Path
from package_ultra import ROOT, QA, BASE, sha

REQUIRED=['source-input-forward','source-core-forward','source-ranking-forward','source-race-forward',
          'source-contacts-forward','source-audit-forward','source-physics-forward',
          'source-ui-forward','source-ui-compatibility','source-polish-forward','source-polish-compatibility',
          'source-content-forward','source-unit-forward','source-release278-compatibility',
          'export-core-forward','export-unit-forward','export-release278-forward','export-release278-compatibility',
          'export-contacts-forward','export-capture-forward','source-capture-compatibility',
          'source-loading-forward','source-loading-compatibility','source-refinements-forward','source-refinements-compatibility',
          'export-loading-forward','export-loading-compatibility','export-refinements-forward','export-refinements-compatibility',
          'export-ui-forward','export-ui-compatibility','export-contacts-compatibility','export-speedometer-forward','export-speedometer-compatibility']

def summarize():
    processes={name:json.loads((QA/name/'process.json').read_text(encoding='utf-8')) for name in REQUIRED}
    failed=[name for name,row in processes.items() if row['status']!='PASS']
    if failed:raise RuntimeError('Unresolved required checks: '+', '.join(failed))
    core_hash=sha(BASE/'LeoRacer.pck')
    stale=[name for name,row in processes.items() if name.startswith('export-') and row.get('core_sha256')!=core_hash]
    if stale:raise RuntimeError('Export results do not match final core: '+', '.join(stale))
    performance=[]
    for path in sorted((QA/'performance').glob('*/performance.json')):
        value=json.loads(path.read_text(encoding='utf-8'))
        for row in value['cases']:performance.append(dict(row,build=path.parent.name,initialization_ms=value['initialization_ms']))
    if len(performance)!=14:raise RuntimeError('Expected fourteen baseline, new-view and previous-candidate cockpit performance cases')
    report={'status':'FUNCTIONAL_PASS','processes':processes,'performance':performance,
            'performance_goal_ms':16.7,'performance_misses':[r for r in performance if r['p95_ms']>16.7],
            'core_sha256':sha(BASE/'LeoRacer.pck'),'physical_4k_tv':'UNVERIFIED','physical_controllers':'UNVERIFIED','physical_wheel':'UNVERIFIED'}
    (QA/'summary.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    features=json.loads((QA/'export-release278-forward/release278.json').read_text(encoding='utf-8'))
    units=json.loads((QA/'export-unit-forward/release278-unit.json').read_text(encoding='utf-8'))
    ui=[json.loads((QA/('source-ui-'+r)/'ui.json').read_text(encoding='utf-8'))['checks'] for r in ['forward','compatibility']]
    loading=json.loads((QA/'export-loading-forward/loading.json').read_text(encoding='utf-8'))
    refinements=json.loads((QA/'export-refinements-forward/refinements278.json').read_text(encoding='utf-8'))
    contacts=json.loads((QA/'export-contacts-forward/contacts.json').read_text(encoding='utf-8'))
    audio=json.loads((QA/'audio-audit.json').read_text(encoding='utf-8'))
    assert audio['status']=='PASS'
    text=f'''# Leo Racer 2.7.8 validation

All {len(REQUIRED)} required functional processes passed. Raw logs, screenshots, collision videos and machine-readable results are in the Evidence ZIP. Installer/portable preservation results are recorded separately in `delivery.json` after packaging.

## Preservation and functional results

The branch starts from 2.7.1 commit `a34196e`. Original release packages and synced `sources/` were retained. Source-preservation tools passed nine original-model hashes and 78 inherited geometry/track comparisons; the Bigster asset audit also passed. Core metadata is optional; Vehicle API 1 remains compatible.

| Check | Result |
|---|---|
| Input / rankings / local race | 35 / 26 / 21 checks passed |
| Core | 54 checks passed in source and native export |
| New settings/camera/contact regressions | {features['checks']} native checks passed per renderer |
| Focused migration/metadata/budget checks | {units['checks']} native checks passed; included in headless CI |
| Collision contacts / vehicle audit | {contacts["checks"]} / 153 checks passed |
| Compact race-loading guide | {loading["checks"]} native checks passed; all ordered device combinations at 720p, 1080p and rendered 4K |
| Cockpits, controller A, throttle, mirrors and playlist | {refinements["checks"]} native checks passed per renderer |
| Offline audio | 36 recordings decoded and checked against bundled hashes; peaks below clipping |
| Content | 449 checks passed |
| UI typography, pointer, keyboard and injected controller | {ui[0]} Forward+ / {ui[1]} Compatibility checks passed |
| Camera/presentation polish | 255 checks passed per renderer |
| Production vehicle-physics matrix | 2,228 checks passed; all six racers finished 1, 3 and 10 laps on all three tracks |

The free-space Bigster replay against the original 2.7.1 driving function recorded zero speed, heading, velocity and boost-fuel differences. The physics matrix uses production collision shapes and omits vehicle presentation for repeatability. The final source matrix includes the barrier rebound refinement; focused native regressions additionally verify that stationary/underpowered pushes cannot earn a gate while a self-driven glancing crossing still counts. Native collision tests and both renderer camera/settings suites run with SDK paths removed.

Repeated exported fullscreen sessions use isolated fresh and then existing test data, with three race/restart cycles per launch and injected app focus notifications. The monitor reported 1920 x 1200 native fullscreen output; the test requested 1920 x 1080 before entering fullscreen. This is not a physical 1080p-only monitor test. Physical OS focus switching remains unverified. Digital speed was checked through actual pixel differences for 000, 099, 199 and 249, not only label properties. Screenshots include 720p/1080p settings, Chase/Ghost/Cockpit, split-screen, reviewed Bigster/Duster hull overlays and night-time visibility. The shared lighting-receiver layer cannot reveal the hidden Ghost car. Camera selection stays in settings; per-player camera actions are exercised independently.

## Final refinement evidence

The compact guide is explicitly race-only. Startup, track changes and a subsequent general operation remain guide-free. Six primary actions retain connectors; secondary actions show saved bindings, including custom and unassigned values. Keyboard artwork is derived at runtime from supplied SVG groups to show assigned driving keys without leaders across unrelated keys. Original SVGs and anchors remain intact.

Physical barrier tests on all three tracks retain containment and checkpoint integrity while producing bounded outward separation under held throttle. Vehicle-pair tests cover head-on, rear-end and side impacts. Changed collision behavior uses the existing 2.7.8 contact namespace.

Shared-world mirror probes confirm live geometry reaches every mirror texture. Forward-view and head-look tests verify update gating. Countdown videos combine actual rendered frames with bundled announcement recordings on the diagnostic cue timeline; they are not a loopback recording of the full game audio mix.

## Measured performance

Windows, NVIDIA RTX A1000 6 GB laptop GPU, driver 566.14, Godot 4.7.2 .NET; native offscreen, non-minimized windows, 1920×1080, Medium, six racers, normal process priority, VSync disabled, 120 FPS ceiling. Runs were sequential without another game test workload. Each case uses six seconds of first-use warmup and a ten-second warmed wall-clock sample. This is a focused diagnostic comparison, not the older 48-case performance certification.

Fresh processes reuse warmed OS/driver caches; single runs and default-setting differences limit causal conclusions. These are default-setting comparisons: the previous solo default used MSAA 4×, the candidate uses MSAA 2×; split-screen uses MSAA 2×. The previous local 2.7.8 candidate is additionally measured with the same cockpit probe. Its camera framing differs, so that comparison is not an isolated mirror-cost experiment. Warm mirror update rates are retained per case; cockpit first-use sampling includes left/right head-look before the centred warmed sample. Neither build uses upscaling or motion blur in these samples. Differences therefore do not isolate collision or camera implementation cost.

Initialization measures scene initialization after bootstrap; complete startup stage timestamps remain in each process log. Loading measures race preparation. First-use peaks cover the six seconds before warmed sampling. Warmed peaks and raw per-frame samples remain separate.

| Build / renderer | Track / players / view | Load ms | First-use peak ms | Warm p50 / p95 / p99 ms | Warm peak ms | p95 ≤16.7 ms |
|---|---|---:|---:|---:|---:|---|
'''
    for row in performance:
        text+=f"| {row['build']} | {row['track']} / {row['humans']} / {row['camera']} | {row['loading_ms']:.1f} | {row['first_use_peak_ms']:.1f} | {row['p50_ms']:.2f} / {row['p95_ms']:.2f} / {row['p99_ms']:.2f} | {row['peak_ms']:.1f} | {'PASS' if row['p95_ms']<=16.7 else 'MISS'} |\n"
    text+='\n### Warm cockpit mirror workload\n\n| Renderer | Previous rear / left / right updates per second | Final rear / left / right updates per second |\n|---|---:|---:|\n'
    for renderer in ['forward','compatibility']:
        rates=[]
        for build in ['2.7.8-previous-'+renderer,'2.7.8-'+renderer]:
            row=next(r for r in performance if r['build']==build and r['camera']=='cockpit')
            values=row['warm_mirror_updates_per_second']
            rates.append(' / '.join(f"{values.get(name+'LiveMirror',0.):.2f}" for name in ['Rear','Left','Right']))
        text+=f"| {renderer} | {rates[0]} | {rates[1]} |\n"
    text+='''
## Limits and launch instructions

- The original intermittent missing-speed trigger was not conclusively reproduced. The affected rendering path is hardened and bounded focus/resize diagnostics are included. Physical 4K-TV hotplug/scaling remains **UNVERIFIED**; windowed/render-size checks do not certify TV behavior.
- Physical gamepad/wheel operation, vibration sensation and wireless reconnect remain **UNVERIFIED**. Injected controls and rumble envelopes pass.
- Startup/first-use and warmed spikes are reported above. No universal locked-60-FPS claim is made. Existing renderer texture/resource shutdown warnings remain in raw logs; they are not silently converted into functional failures or claimed fixed.
- The .NET build passed with cached dependencies; the restricted network prevented the optional NuGet vulnerability lookup (NU1900 warnings).
- The 32-bit NSIS loader could not run in the normal build sandbox (WinError 623). Installer compilation/isolated installer tests require the reviewed native build path; their final outcome is in the Evidence ZIP's `delivery.json`.

Extract the portable ZIP into a new folder and run `LeoRacer.exe`, or use `Play Compatibility.cmd`. Keep the full folder together. No SDK, account or network is needed. Press C/right-stick click for camera selection; V/left-stick click is the default look-back. Bigster and Duster 2024 have reviewed Cockpit views, with the approved animated wheel, stalk removal, live displays and a centred road-facing camera. Rear mirrors run at 128 x 64 / 10 Hz; side updates are gated on relevant head-look. Generic wheel button callouts use explicit button IDs where hardware-specific positions are unknown. Settings and historical records are retained; consult RELEASE_NOTES.md for the new contact namespace and custom-binding migration.
'''
    (ROOT/'docs/VALIDATION_278.md').write_text(text,encoding='utf-8')
    print('VALIDATION278_SUMMARIZED',len(processes),'processes',len(performance),'performance cases',len(report['performance_misses']),'p95 misses',flush=True)

if __name__=='__main__':summarize()
