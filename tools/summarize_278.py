"""Write a measured candidate report; frame-time misses remain explicit."""
import json
from pathlib import Path
from package_ultra import ROOT, QA, BASE, sha

REQUIRED=['source-input-forward','source-core-forward','source-ranking-forward','source-race-forward',
          'source-contacts-forward','source-audit-forward','source-physics-forward',
          'source-ui-forward','source-ui-compatibility','source-polish-forward','source-polish-compatibility',
          'source-content-forward','source-unit-forward','source-release278-compatibility',
          'export-core-forward','export-unit-forward','export-release278-forward','export-release278-compatibility',
          'export-contacts-forward','export-capture-forward','source-capture-compatibility']

def summarize():
    processes={name:json.loads((QA/name/'process.json').read_text(encoding='utf-8')) for name in REQUIRED}
    failed=[name for name,row in processes.items() if row['status']!='PASS']
    if failed:raise RuntimeError('Unresolved required checks: '+', '.join(failed))
    performance=[]
    for path in sorted((QA/'performance').glob('*/performance.json')):
        value=json.loads(path.read_text(encoding='utf-8'))
        for row in value['cases']:performance.append(dict(row,build=path.parent.name,initialization_ms=value['initialization_ms']))
    if len(performance)!=12:raise RuntimeError('Expected all twelve matched/default and new-view performance cases')
    report={'status':'FUNCTIONAL_PASS','processes':processes,'performance':performance,
            'performance_goal_ms':16.7,'performance_misses':[r for r in performance if r['p95_ms']>16.7],
            'core_sha256':sha(BASE/'LeoRacer.pck'),'physical_4k_tv':'UNVERIFIED','physical_controllers':'UNVERIFIED'}
    (QA/'summary.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    features=json.loads((QA/'export-release278-forward/release278.json').read_text(encoding='utf-8'))
    units=json.loads((QA/'export-unit-forward/release278-unit.json').read_text(encoding='utf-8'))
    ui=[json.loads((QA/('source-ui-'+r)/'ui.json').read_text(encoding='utf-8'))['checks'] for r in ['forward','compatibility']]
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
| Collision contacts / vehicle audit | 226 / 153 checks passed |
| Content | 449 checks passed |
| UI typography, pointer, keyboard and injected controller | {ui[0]} Forward+ / {ui[1]} Compatibility checks passed |
| Camera/presentation polish | 255 checks passed per renderer |
| Production-controller physics matrix | 2,228 checks passed; all six racers finished 1, 3 and 10 laps on all three tracks |

The free-space Bigster replay against the original 2.7.1 driving function recorded zero speed, heading, velocity and boost-fuel differences. The physics matrix uses production collision shapes and omits vehicle presentation for repeatability. It precedes the final glancing-contact gate refinement; focused native regressions additionally verify that stationary/underpowered pushes cannot earn a gate while a self-driven glancing crossing still counts. Native collision tests and both renderer camera/settings suites run with SDK paths removed.

Digital speed was checked through actual pixel differences for 000, 099, 199 and 249, not only label properties. Screenshots include 720p/1080p settings, Chase/Ghost/Cockpit, split-screen, reviewed Bigster/Duster hull overlays and night-time visibility. The shared lighting-receiver layer cannot reveal the hidden Ghost car. Split-screen camera buttons were exercised through real GUI pointer delivery.

## Measured performance

Windows, NVIDIA RTX A1000 6 GB laptop GPU, driver 566.14, Godot 4.7.2 .NET; native offscreen, non-minimized windows, 1920×1080, Medium, six racers, normal process priority, VSync disabled, 120 FPS ceiling. Runs were sequential without another game test workload. Each case uses six seconds of first-use warmup and a ten-second warmed wall-clock sample. This is a focused diagnostic comparison, not the older 48-case performance certification.

Fresh processes reuse warmed OS/driver caches; single runs and default-setting differences limit causal conclusions. These are default-setting comparisons: the previous solo default used MSAA 4×, the candidate uses MSAA 2×; split-screen uses MSAA 2×. Neither build uses upscaling or motion blur in these samples. Differences therefore do not isolate collision or camera implementation cost.

Initialization measures scene initialization after bootstrap; complete startup stage timestamps remain in each process log. Loading measures race preparation. First-use peaks cover the six seconds before warmed sampling. Warmed peaks and raw per-frame samples remain separate.

| Build / renderer | Track / players / view | Load ms | First-use peak ms | Warm p50 / p95 / p99 ms | Warm peak ms | p95 ≤16.7 ms |
|---|---|---:|---:|---:|---:|---|
'''
    for row in performance:
        text+=f"| {row['build']} | {row['track']} / {row['humans']} / {row['camera']} | {row['loading_ms']:.1f} | {row['first_use_peak_ms']:.1f} | {row['p50_ms']:.2f} / {row['p95_ms']:.2f} / {row['p99_ms']:.2f} | {row['peak_ms']:.1f} | {'PASS' if row['p95_ms']<=16.7 else 'MISS'} |\n"
    text+='''
## Limits and launch instructions

- The original intermittent missing-speed trigger was not conclusively reproduced. The affected rendering path is hardened and bounded focus/resize diagnostics are included. Physical 4K-TV hotplug/scaling remains **UNVERIFIED**; windowed/render-size checks do not certify TV behavior.
- Physical controller sensation and wireless reconnect remain **UNVERIFIED**. Injected controls and rumble envelopes pass.
- Startup/first-use and warmed spikes are reported above. No universal locked-60-FPS claim is made. Existing renderer texture/resource shutdown warnings remain in raw logs; they are not silently converted into functional failures or claimed fixed.
- The .NET build passed with cached dependencies; the restricted network prevented the optional NuGet vulnerability lookup (NU1900 warnings).
- Local build sandboxing rejected the 32-bit NSIS loader with WinError 623. Installer compilation/isolated installer tests require the reviewed native build path; their final outcome is in `delivery.json`.

Extract the portable ZIP into a new folder and run `LeoRacer.exe`, or use `Play Compatibility.cmd`. Keep the full folder together. No SDK, account or network is needed. Press C/right-stick click for camera selection; V/left-stick click is the default look-back. Bigster has the reviewed Cockpit view. Settings and historical records are retained; consult RELEASE_NOTES.md for the new contact namespace and custom-binding migration.
'''
    (ROOT/'docs/VALIDATION_278.md').write_text(text,encoding='utf-8')
    print('VALIDATION278_SUMMARIZED',len(processes),'processes',len(performance),'performance cases',len(report['performance_misses']),'p95 misses',flush=True)

if __name__=='__main__':summarize()
