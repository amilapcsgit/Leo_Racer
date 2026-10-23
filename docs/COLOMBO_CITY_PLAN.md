# Colombo city recovery journal

Base: v1.7.0 source commit ac37cc6c0cb6c0f5bbbb3059fe5496974442c852.
Branch: colombo-city. Published releases are not modified or republished.

## Contract

- Colombo-inspired, offline 5–6 km circuit (target 5.5 km), three laps, six racers.
- Retain selectable Astra Lotus Coast, single player and two-player shared-world split screen.
- Preserve Lotus Tower, Galle Face Green, existing custom architecture, all vehicles/drivers, Bigster 130% size and wheel bindings.
- External GameAssets category packs with registered loose GLB/PNG/SVG overrides. Core executable/package contain no heavy game art.
- Animated staged loading, lazy garage models, compatible manifest-discovered future tracks.
- Baked road/route/collision, variable widths, safe grid/checkpoints/recovery from the same definition.
- Reusable licensed supplied buildings, spatial batches and approximately 200 m scenery cells demanded by both cameras.
- Existing warm daylight polished; free roam, traffic, night cycle and live map downloads excluded.
- Records separated by track/revision; preserve existing Astra/legacy data.
- Commit and push tested checkpoints; development artifacts only.

## Checkpoints

1. Branch and baseline: COMPLETE. Protected hashes recorded, original source/Bigster checks and 35 input checks pass; five baseline Vulkan section captures in build/city-baseline. Prior released RTX A1000 baseline: 99.7 FPS Vulkan / 82.9 Compatibility.
2. External assets, loading and installer: COMPLETE. External category packs deduplicate byte-identical resources; 109,579,776-byte engine executable, 10,665,664-byte core in initial trial. 12 asset-contract checks, 96 driver/vehicle combinations (2687 assertions), 21 race checks, 21 presentation checks and 11 driving checks pass. Exported offline smoke passes, including split views and native SQLite. Installer creates hybrid content folders and has a separate Development installation identity. Main/preview loading is asynchronous; direct scene tests await initialization. Resource cleanup warnings are retained in logs, not counted as functional passes.
3. Track definitions, selection and ranking migration: COMPLETE. 27 track/record integration checks, 26 legacy ranking checks and 21 race checks pass. Astra points/hash unchanged; local widths and spatial projection are data-driven. Track selector and revision filters added. Supplemental session_courses table preserves the v1 database schema/API and records. No ALTER or destructive migration.
4. Expanded baked course and driving: COMPLETE. Road Generator 0.9.5 MIT addon pinned; 22 editable RoadPoints bake a script-free 5,499.995 m course with 2,750 uniform samples, 18–24 m widths, resident road/barrier collision, start/grid/checkpoints/recovery and updated minimaps. Numeric audit: minimum radius 54.9 m, nonlocal centerline clearance 112.1 m, no crossings. Upward normals and 11 driving checks pass. Full three-lap split-screen race passes: both humans and all four AI finish, 10 integration checks. Offline OSM reference acquired/pruned with attribution; raw/runtime map downloads are unnecessary. Scenery cells intentionally empty until checkpoint 5.
5. Colombo building library, landmarks, streaming and daylight: COMPLETE. 34 attributed premade models and 4 infrastructure pieces extracted; final layout has 295 street buildings, 176 skyline buildings, 416 palms, 250 fitted railing sections, 54 cells, shared geometry/textures and readable outlined SVG/PNG signs. Pavilion/pool triangle subsets retained exactly; obsolete original track furniture excluded. Actual Vulkan nine-view contact sheet inspected, including Lotus Tower, Galle Face Green and pavilion. Headless MultiMesh serialization issue fixed with explicit CPU buffers and runtime restoration. 35 streaming/memory checks pass: 14 initial cells, 12 cache entries, 917 stable nodes and 355.36 MB CPU allocation across three track-change cycles. Asset recovery/overrides and lazy driver metadata validated. Initial RTX A1000 split-screen profiles exceed 60 FPS in Vulkan and Compatibility; final separated-camera check and offline installer follow in checkpoint 6.
6. Regression, performance and offline package: COMPLETE locally. Both three-lap modes, original-track regressions, separated-camera RTX A1000 profiles, extracted offline package and isolated installer checks pass. Final layout has 53 occupied scenery cells; the earlier 54-cell count preceded removal of obsolete skyline furniture. The checked Godot template avoids an optimized-template diagnostic shutdown fault. See COLOMBO_CITY_VALIDATION.md and qa-colombo-city/.

User follow-up on 2026-10-23 explicitly authorizes publishing 1.8 after extensive manual play of both tracks, with look-and-feel work deferred. Prepare release/1.8.0 from this implementation; CI creates v1.8.0 and publishes only after its package checks pass. Previously published v1.7.0 remains unchanged.

## Sources

User-supplied input directory: C:/Users/amilapcs/Downloads/Leo Racer/colombo-city (read without changing originals).
Road Generator 0.9.5: supplied ZIP, MIT; editor authoring/bake only.
OpenStreetMap Racer: architectural study only; no code copied (license not located).
OSM extracts, where used, remain offline and carry ODbL attribution/source details.
City Game Ready Free (CG Lads), Low-poly City Buildings (smooth998), City infrastructure Map 3 (PropShop): embedded CC-BY-4.0 metadata.
Night skyscrapers: embedded Sketchfab Standard metadata; excluded from redistributable assets until rights documented.
Untitled.glb: no embedded provenance; excluded from redistribution.

## Verification

Pinned Godot 4.7.2 .NET, bundled .NET SDK, Python NumPy/Pillow, Blender 4.5.
Start with git status and this journal. Never edit sources/ or protected source vehicle geometry.
Existing tools/check_local2player.ps1 covers input, shared race, presentation, rankings, driver and Bigster regressions.
City checks must cover manifest failures/overrides, track revisions, course geometry, two-camera streaming, cold/warm loading, both renderer modes, full races, and extracted offline packaging.
Report engine/core/assets/track/installed/ZIP sizes separately. Measure 1080p RTX A1000 six-racer split screen; target 60 FPS.
Do not claim visual or hardware validation from static/export checks.
