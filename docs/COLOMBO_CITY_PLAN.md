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

1. Branch and baseline: IN PROGRESS.
2. External assets, loading and installer: pending.
3. Track definitions, selection and ranking migration: pending.
4. Expanded baked course and driving: pending.
5. Colombo building library, landmarks, streaming and daylight: pending.
6. Regression, performance and offline development package: pending.

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
