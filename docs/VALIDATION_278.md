# Leo Racer 2.7.8 validation

All 21 required functional processes passed. Raw logs, screenshots, collision videos and machine-readable results are in the Evidence ZIP. Installer/portable preservation results are recorded separately in `delivery.json` after packaging.

## Preservation and functional results

The branch starts from 2.7.1 commit `a34196e`. Original release packages and synced `sources/` were retained. Source-preservation tools passed nine original-model hashes and 78 inherited geometry/track comparisons; the Bigster asset audit also passed. Core metadata is optional; Vehicle API 1 remains compatible.

| Check | Result |
|---|---|
| Input / rankings / local race | 35 / 26 / 21 checks passed |
| Core | 54 checks passed in source and native export |
| New settings/camera/contact regressions | 107 native checks passed per renderer |
| Focused migration/metadata/budget checks | 43 native checks passed; included in headless CI |
| Collision contacts / vehicle audit | 226 / 153 checks passed |
| Content | 449 checks passed |
| UI typography, pointer, keyboard and injected controller | 1059 Forward+ / 1063 Compatibility checks passed |
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
| 2.7.1-compatibility | astra_coast / 1 / chase | 12524.6 | 645.0 | 7.66 / 9.84 / 11.24 | 1235.3 | PASS |
| 2.7.1-compatibility | kandy_lake / 2 / chase | 9284.0 | 3235.8 | 9.67 / 16.46 / 34.27 | 330.9 | PASS |
| 2.7.1-forward | astra_coast / 1 / chase | 11732.0 | 18.5 | 8.91 / 10.14 / 10.57 | 11.7 | PASS |
| 2.7.1-forward | kandy_lake / 2 / chase | 14291.2 | 52.9 | 10.08 / 12.36 / 20.10 | 27.5 | PASS |
| 2.7.8-compatibility | astra_coast / 1 / chase | 12590.7 | 605.6 | 7.62 / 9.84 / 10.29 | 1151.7 | PASS |
| 2.7.8-compatibility | kandy_lake / 2 / chase | 9291.0 | 3725.7 | 9.37 / 16.25 / 27.75 | 313.2 | PASS |
| 2.7.8-compatibility | astra_coast / 1 / ghost | 1351.2 | 10.1 | 8.33 / 9.84 / 10.03 | 82.7 | PASS |
| 2.7.8-compatibility | astra_coast / 1 / cockpit | 580.6 | 10.2 | 7.64 / 9.83 / 10.14 | 22.3 | PASS |
| 2.7.8-forward | astra_coast / 1 / chase | 11726.8 | 30.5 | 9.04 / 9.83 / 10.21 | 10.9 | PASS |
| 2.7.8-forward | kandy_lake / 2 / chase | 13638.0 | 40.9 | 10.29 / 12.82 / 20.30 | 28.3 | PASS |
| 2.7.8-forward | astra_coast / 1 / ghost | 5206.3 | 17.4 | 8.88 / 9.87 / 10.24 | 11.8 | PASS |
| 2.7.8-forward | astra_coast / 1 / cockpit | 1936.1 | 10.4 | 8.84 / 10.04 / 10.63 | 11.3 | PASS |

## Limits and launch instructions

- The original intermittent missing-speed trigger was not conclusively reproduced. The affected rendering path is hardened and bounded focus/resize diagnostics are included. Physical 4K-TV hotplug/scaling remains **UNVERIFIED**; windowed/render-size checks do not certify TV behavior.
- Physical controller sensation and wireless reconnect remain **UNVERIFIED**. Injected controls and rumble envelopes pass.
- Startup/first-use and warmed spikes are reported above. No universal locked-60-FPS claim is made. Existing renderer texture/resource shutdown warnings remain in raw logs; they are not silently converted into functional failures or claimed fixed.
- The .NET build passed with cached dependencies; the restricted network prevented the optional NuGet vulnerability lookup (NU1900 warnings).
- Local build sandboxing rejected the 32-bit NSIS loader with WinError 623. Installer compilation/isolated installer tests require the reviewed native build path; their final outcome is in `delivery.json`.

Extract the portable ZIP into a new folder and run `LeoRacer.exe`, or use `Play Compatibility.cmd`. Keep the full folder together. No SDK, account or network is needed. Press C/right-stick click for camera selection; V/left-stick click is the default look-back. Bigster has the reviewed Cockpit view. Settings and historical records are retained; consult RELEASE_NOTES.md for the new contact namespace and custom-binding migration.
