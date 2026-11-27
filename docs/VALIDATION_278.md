# Leo Racer 2.7.8 validation

All 34 required functional processes passed. Raw logs, screenshots, collision videos and machine-readable results are in the Evidence ZIP. Installer/portable preservation results are recorded separately in `delivery.json` after packaging.

## Preservation and functional results

The branch starts from 2.7.1 commit `a34196e`. Original release packages and synced `sources/` were retained. Source-preservation tools passed nine original-model hashes and 78 inherited geometry/track comparisons; the Bigster asset audit also passed. Core metadata is optional; Vehicle API 1 remains compatible.

| Check | Result |
|---|---|
| Input / rankings / local race | 35 / 26 / 21 checks passed |
| Core | 54 checks passed in source and native export |
| New settings/camera/contact regressions | 124 native checks passed per renderer |
| Focused migration/metadata/budget checks | 58 native checks passed; included in headless CI |
| Collision contacts / vehicle audit | 235 / 153 checks passed |
| Compact race-loading guide | 19784 native checks passed; all ordered device combinations at 720p, 1080p and rendered 4K |
| Cockpits, controller A, throttle, mirrors and playlist | 73 native checks passed per renderer |
| Offline audio | 36 recordings decoded and checked against bundled hashes; peaks below clipping |
| Content | 449 checks passed |
| UI typography, pointer, keyboard and injected controller | 1059 Forward+ / 1063 Compatibility checks passed |
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
| 2.7.1-compatibility | astra_coast / 1 / chase | 10918.0 | 558.2 | 7.58 / 9.89 / 10.37 | 1122.8 | PASS |
| 2.7.1-compatibility | kandy_lake / 2 / chase | 7699.6 | 3174.4 | 9.62 / 15.89 / 34.71 | 344.0 | PASS |
| 2.7.1-forward | astra_coast / 1 / chase | 2183.1 | 22.3 | 8.91 / 10.16 / 10.64 | 11.1 | PASS |
| 2.7.1-forward | kandy_lake / 2 / chase | 6877.2 | 53.1 | 10.09 / 11.86 / 18.98 | 24.5 | PASS |
| 2.7.8-compatibility | astra_coast / 1 / chase | 2095.7 | 201.4 | 7.67 / 9.85 / 10.02 | 17.4 | PASS |
| 2.7.8-compatibility | kandy_lake / 2 / chase | 1536.8 | 120.0 | 10.83 / 15.99 / 21.94 | 110.6 | PASS |
| 2.7.8-compatibility | astra_coast / 1 / ghost | 1370.5 | 20.4 | 7.88 / 9.83 / 10.01 | 11.2 | PASS |
| 2.7.8-compatibility | astra_coast / 1 / cockpit | 669.4 | 435.0 | 7.69 / 9.84 / 10.11 | 65.5 | PASS |
| 2.7.8-forward | astra_coast / 1 / chase | 2186.4 | 27.8 | 8.70 / 9.86 / 10.21 | 11.1 | PASS |
| 2.7.8-forward | kandy_lake / 2 / chase | 5080.8 | 56.1 | 9.80 / 12.20 / 18.73 | 23.7 | PASS |
| 2.7.8-forward | astra_coast / 1 / ghost | 3890.4 | 19.3 | 9.03 / 9.88 / 10.12 | 10.5 | PASS |
| 2.7.8-forward | astra_coast / 1 / cockpit | 2008.0 | 92.2 | 9.11 / 10.91 / 11.69 | 12.6 | PASS |
| 2.7.8-previous-compatibility | astra_coast / 1 / cockpit | 1514.7 | 165.7 | 7.99 / 9.88 / 10.22 | 12.1 | PASS |
| 2.7.8-previous-forward | astra_coast / 1 / cockpit | 2347.7 | 63.3 | 8.95 / 11.22 / 11.96 | 15.4 | PASS |

### Warm cockpit mirror workload

| Renderer | Previous rear / left / right updates per second | Final rear / left / right updates per second |
|---|---:|---:|
| forward | 12.49 / 12.49 / 12.59 | 9.60 / 0.00 / 0.00 |
| compatibility | 13.30 / 13.30 / 13.40 | 9.19 / 0.00 / 0.00 |

## Limits and launch instructions

- The original intermittent missing-speed trigger was not conclusively reproduced. The affected rendering path is hardened and bounded focus/resize diagnostics are included. Physical 4K-TV hotplug/scaling remains **UNVERIFIED**; windowed/render-size checks do not certify TV behavior.
- Physical gamepad/wheel operation, vibration sensation and wireless reconnect remain **UNVERIFIED**. Injected controls and rumble envelopes pass.
- Startup/first-use and warmed spikes are reported above. No universal locked-60-FPS claim is made. Existing renderer texture/resource shutdown warnings remain in raw logs; they are not silently converted into functional failures or claimed fixed.
- The .NET build passed with cached dependencies; the restricted network prevented the optional NuGet vulnerability lookup (NU1900 warnings).
- The 32-bit NSIS loader could not run in the normal build sandbox (WinError 623). Installer compilation/isolated installer tests require the reviewed native build path; their final outcome is in the Evidence ZIP's `delivery.json`.

Extract the portable ZIP into a new folder and run `LeoRacer.exe`, or use `Play Compatibility.cmd`. Keep the full folder together. No SDK, account or network is needed. Press C/right-stick click for camera selection; V/left-stick click is the default look-back. Bigster and Duster 2024 have reviewed Cockpit views, with the approved animated wheel, stalk removal, live displays and a centred road-facing camera. Rear mirrors run at 128 x 64 / 10 Hz; side updates are gated on relevant head-look. Generic wheel button callouts use explicit button IDs where hardware-specific positions are unknown. Settings and historical records are retained; consult RELEASE_NOTES.md for the new contact namespace and custom-binding migration.
