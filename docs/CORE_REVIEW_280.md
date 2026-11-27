# Leo Racer 2.8 core review

Baseline: `v2.7.9` (`09357fd`) to `v2.8.0` (`954733d`), followed by an audit of the current core. Work is tracked in [review #6](https://github.com/amilapcsgit/Leo_Racer/issues/6).

## Standards

- **P1: recorded tire playback was unreachable.** The player array was empty and packaged recordings suppressed the legacy skid player. Both recorded layers are now instantiated and routed to the vehicle bus. Legacy playback remains available when either recording is unavailable. [Task #7](https://github.com/amilapcsgit/Leo_Racer/issues/7).
- Environment registration now gives explicit surface metadata precedence; names and shader-source detection remain compatibility fallbacks for older content.
- No pre-existing dedicated coding standards were found. The shader-identity finding was a maintainability judgment, not a documented-standard violation.

## Spec

- Release notes promised scrub-to-squeal blending; the tire initialization defect contradicted that promise.
- Historical requirements came from release notes, validation notes and the release manifest. No original 2.8 implementation specification was found.
- Historical 1024×576 stationary-camera measurements do not establish full moving-race performance at 1080p. See the separate performance evidence produced by this work.

## Wider core

- **Equal finish times:** reproduced P2 crossing first but ranking behind P1 when both events shared one render-frame timestamp. An explicit crossing-order tie-break fixes this without changing saved record formats or displayed times. [Task #10](https://github.com/amilapcsgit/Leo_Racer/issues/10).
- **Pause-time car replacement:** reproduced an out-of-bounds placement with a 6 m route-width fixture. Replacement uses the local road width and surface frame, rejects an oversized car and retains circuit distance/checkpoints. [Task #11](https://github.com/amilapcsgit/Leo_Racer/issues/11).
- Ordered gates, anti-push crossing checks, recovery, retirement, input ownership, disconnect handling, records validation and guarded content workers were inspected. Suspected issues were kept separate from reproduced defects.
- **Detached streaming anchors:** the frozen native baseline's intermittent transform diagnostic was reproduced by a rendered restart loop. Local player slots retained valid-but-detached racer objects, which scenery prioritization/grass streaming read as world-space anchors. Active references are now cleared before detach, and both scenery consumers require tree membership. A minimized red-capable probe passed after the fix; the full 50-restart rendered loop also passed in source and native. [Task #12](https://github.com/amilapcsgit/Leo_Racer/issues/12).

## Optimization approach

The original synchronous grass builder measured 9.701 ms median, 16.588 ms p95 and 16.963 ms maximum across 60 sampled Astra tiles in a headless CPU probe. Native moving races also recorded substantially larger first-use tile peaks. This identifies real CPU work; it is not a rendered FPS claim.

Tile work is spread across scene-process slices, with cancellation when terrain changes or a tile leaves the wanted area. The time budget is cooperative: mesh extraction, a candidate's intersection checks and GPU upload can overshoot a slice and are measured rather than claimed as a hard real-time limit. Deterministic placements are compared with the pinned release implementation.

Circuit projection caches stable, ordered candidate lists and removes duplicate segment visits. AI lane selection evaluates duplicate lanes once. Neither change alters scoring, route geometry or driving rules. Before/after native evidence determines the performance claim.

## Validation status

The source suite passed: core (55 checks), physics (2,228), contacts (244), input (35), ranking (26), race (21), finish (21), audio (36), plus the new targeted regressions below. Red-before-green evidence was retained for tire playback, equal-time finish order and narrow-road replacement. The native core, physics, contacts, input, ranking, race, finish and audio suites also pass. The full moving-race matrix is recorded separately in the performance report.

The historical contact fixture also failed on the frozen release baseline. Its side case assigned velocity before `place()` reset it and began with overlapping rotated bodies. The fixture now computes clearance from actual collision extents/offsets, assigns motion after placement, and requires peer slide contact in every case. Velocity bounds remain unchanged; no contact solver or handling change was made. Contacts and race checks use a rendered backend to avoid headless Dummy-material diagnostics.

The source parity probe passed 2,610 checks against the pinned release: exact projection results, grass transforms/counts, tiny work slices, detail changes and stale-job cancellation. A further 240 AI cases retained identical commands while reducing obstacle queries from 960 to 780. The audio integration passed 38 checks, including isolated non-silent mixed output for recorded tires in solo/split-screen and for the legacy fallback.

The minimized detached-anchor regression passed three checks in 1.03 s. The original rendered 50-restart stress loop then passed with zero runtime errors after the fix. A pre-existing seven-texture Forward+ shutdown warning is recorded separately and is not claimed fixed.

Existing untracked installer/import files were preserved. This work does not publish a release.

## Native QA fixture notes

The first native candidate passed all physics assertions but its headless wrapper reported a Dummy scene-cull error and Dummy mesh shutdown leak. That failed log is retained and the rendered repeat passed all 2,228 assertions with zero runtime errors. The tiny detached-anchor fixture initially depended on a legacy editor-only route file; it now supplies a minimal explicit route. The native input check exposed an intermittent intro-Ogg shutdown leak; the QA adapter now allows 0.5 s for audio drain instead of 0.1 s. Ten native input repeats passed without runtime or shutdown errors. These are test-harness changes, not gameplay changes.

The `after-qa2` candidate has byte-identical production/content pack entries to `after`; all changed entries are under `tests/native270/`. This parity evidence is retained in `build/qa280/candidate-qa-parity.json`. Existing successful native checks remain linked to their exact candidate hashes.
