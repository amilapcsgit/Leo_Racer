# Modularity development

Branch `modularity`, based on released v2.1.0 (`70961b6`). Public releases are unchanged.

## Contract and recovery

Vehicles are authoritative loose GLB + JSON folders. Metadata discovery must not load models. Generated, disposable caches live in user data. Vehicle API 1 and Track API 2 are data-only interfaces; the engine owns physics, input, assembly and streaming. Existing Track API 1 folders remain supported.

Default development profile: Bigster and Duster, six drivers, both tracks, six racers. Full distribution: all sixteen vehicles. Keep existing stable IDs, wheel pivots, Bigster normalization, driver fits and user records. Custom tuning/content excludes affected races from official records. Refresh content only outside races.

## Checkpoints

1. Content contracts, source inventory and baseline measurements.
2. Loose vehicle discovery/import/cache and two-car development profile.
3. Visual vehicle setup, test drive and export.
4. Track starter project and independent core/vehicle/track/distribution targets.
5. Full migration, integration, performance and extracted offline development build.

Commit and push each tested checkpoint. Routine content changes test their dependency closure; full-roster checks run for shared changes and release candidates. No new public release is authorized by this milestone.

## Verification

Evidence belongs under `docs/qa-modularity/`, with machine paths removed before commits. Large captures and temporary packages belong under ignored `build/` and `dist/`. Never rewrite historical release reports.

Baseline and final: six racers using only Bigster/Duster, 1080p, both renderers, identical track/camera conditions. Report cold/warm load duration, p50/p95/p99 frame time, memory and spikes independently. Target 60 FPS and at most 5% steady-state frame-time regression.

Checkpoint 1 verified: sixteen definitions round-trip all 23 transferable fields and wheel bindings; source GLBs are self-contained. Baseline measurements use the original engine loading path and only Bigster/Duster. Core compatibility starts at 2.2.0 (this development branch); no public 2.2 release is implied.

Checkpoint 2 verified: loose Bigster/Duster metadata discovery and threaded cold/warm cache imports (36 checks), independent-player race state (21 checks), and all six racers completing three laps with one human held back until AI finish (10 checks). The race implementation still ends when both humans finish. Missing/duplicate/newer/incomplete entries are isolated. Content manager discovery is available; its setup actions are completed in checkpoint 3.
