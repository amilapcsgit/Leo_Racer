# Modularity development

Branch `modularity`, based on released v2.1.0 (`70961b6`). Prior releases remain unchanged; v2.2.0 publication was authorized after playtesting.

## Contract and recovery

Vehicles are authoritative loose GLB + JSON folders. Metadata discovery must not load models. Generated, disposable caches live in user data. Vehicle API 1 and Track API 2 are data-only interfaces; the engine owns physics, input, assembly and streaming. Existing Track API 1 folders remain supported.

Default development profile: Bigster and Duster, six drivers, both tracks, six racers. Full distribution: all sixteen vehicles. Keep existing stable IDs, wheel pivots, Bigster normalization, driver fits and user records. Custom tuning/content excludes affected races from official records. Refresh content only outside races.

## Checkpoints

1. Content contracts, source inventory and baseline measurements.
2. Loose vehicle discovery/import/cache and two-car development profile.
3. Visual vehicle setup, test drive and export.
4. Track starter project and independent core/vehicle/track/distribution targets.
5. Full migration, integration, performance and extracted offline development build.

Commit and push each tested checkpoint. Routine content changes test their dependency closure; full-roster checks run for shared changes and release candidates. The original milestone requested development artifacts. After playing the build, the user explicitly authorized publication as v2.2.0.

## Verification

Evidence belongs under `docs/qa-modularity/`, with machine paths removed before commits. Large captures and temporary packages belong under ignored `build/` and `dist/`. Never rewrite historical release reports.

Baseline and final: six racers using only Bigster/Duster, 1080p, both renderers, identical track/camera conditions. Report cold/warm load duration, p50/p95/p99 frame time, memory and spikes independently. Target 60 FPS and at most 5% steady-state frame-time regression.

Checkpoint 1 verified: sixteen definitions round-trip all 23 transferable fields and wheel bindings; source GLBs are self-contained. Baseline measurements use the original engine loading path and only Bigster/Duster. Core compatibility starts at 2.2.0 (this development branch); no public 2.2 release is implied.

Checkpoint 2 verified: loose Bigster/Duster metadata discovery and threaded cold/warm cache imports (36 checks), independent-player race state (21 checks), and all six racers completing three laps with one human held back until AI finish (10 checks). The race implementation still ends when both humans finish. Missing/duplicate/newer/incomplete entries are isolated. Content manager discovery is available; its setup actions are completed in checkpoint 3.

Checkpoint 3: vehicle workshop validated 22 checks, including four wheel pivots, six driver previews, Bigster scale once, unsaved tuned test-drive physics, portable folder export and discovery without rebuilding. Private drive runs in a separate world and cannot write race results. A 720p capture was inspected and footer/layout corrected. Authoring texture optimization produces loose DDS sidecars (Pony test: 14 texture bindings); runtime only reads compressed images, with export-template validation in checkpoint 5.

Checkpoint 4 verified: independent Track API 2 starter project exports a 753.95 m example with resident collision, eight safe recoveries, route helpers and two decorative cells. Six racers completed three laps (8 checks). Both original Track API 1 folders remain compatible. Core, individual vehicle/track, SDK and assembled distribution targets are separate; a Duster/Astra rebuild left executable/core hashes unchanged. Twelve packs were audited with zero packed vehicle models. CI selects dependency-specific checks and uploads development artifacts only.

Shared-change migration validation passed 1,205 checks across all sixteen cars and six drivers (96 assemblies), including measured wheel travel, pivots, cabin identity and legacy selection migration. Selective loose-cache invalidation passed 40 checks; unchanged cars remain in memory. Runtime metadata scanning runs on a worker while the loading screen animates. Final exported-template, installation and performance evidence follows in checkpoint 5.

Checkpoint 5: extracted development builds passed offline import, official fingerprints, stock-track loading, SQLite/UI, custom compressed textures, a contributor vehicle and the SDK track without changes to executable/core hashes. All sixteen folders contain loose model, metadata, thumbnail and license files; no shipped vehicle models remain in packs. Installer install/update/uninstall preserves unknown community folders. Final acceptance and package sizes are recorded in MODULARITY_VALIDATION.md.

Release follow-up: Refresh Content now scans on a worker with visible progress, leaves the content screen focused, removes stale rows immediately and refreshes automatically after leaving the workshop. Empty-roster management remains accessible. The actual button and workshop-return regression test checks six cases, including newly dropped GLBs, newly configured folders, removal and the race guard.

Final release acceptance: four three-lap races (both tracks × one/two humans), the extracted two-car package and installed sixteen-car package passed. Final package CRC/model-source audits, cold/warm timings and installer preservation evidence are under docs/qa-modularity.
