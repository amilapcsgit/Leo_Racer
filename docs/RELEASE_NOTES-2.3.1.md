# Leo Racer 2.3.1 — Kandy Lake

Kandy has grounded landmarks, physical signs and a start arch, a new daylight environment, and deeper mountain scenery. Corrupted startup/loading punctuation and imported landmark node-name conflicts are fixed.

## Changes

- Advertising sits beyond the outer pavement, faces approaching racers, and has reserved clear space. English, Sinhala and Tamil sign artwork replaces floating Kandy labels.
- A grounded truss carries the **LEO RACER / KANDY LAKE** start banner. Sri Lankan flags keep their hoist attached to the pole, with a natural reverse face.
- A 4096×2048 panorama and linear HDR EXR provide daylight and reflections. Three fixed mountain layers add real translation parallax. Temple, stupa and start precincts retain baked indirect illumination through streaming and export.
- The supplied Tooth Temple replaces the damaged model. The white stupa is grounded without its dark lower supports. Buddha, jungle temple and CEYPETCO models are integrated with their source textures; unwanted source ground helpers are removed from runtime copies.
- Loading messages, race summaries and related copy use correct ellipses, separators and dashes. The existing Kandy route, handling, checkpoints and course revision remain unchanged.

## Downloads

Use **LeoRacer-Setup-2.3.1.exe** for installation or upgrade, or extract **LeoRacer-2.3.1-win64.zip** and run `LeoRacer.exe`. Both include all three tracks and the 16 default cars. The installer offers 32 optional cars; portable users can add selected folders from the AdditionalCars ZIP.

The standalone **KandyLake** ZIP requires core **2.3.1**. Copy its `GameAssets` folder into a 2.3.1 installation. Settings and records retain their existing user-data location; installer ownership tracking preserves user-added cars and backs up replaced modifications. v2.3.0 remains available.

The **Kandy-Evidence** ZIP contains matching full-lap before/after images, landmark and signage close-ups, loading screenshots, and acceptance/performance results. Attribution, installed sizes and SHA-256 checksums are provided separately.

## Validation and limits

Validated exported surfaces, landmarks, materials, malformed content, streaming/track changes, three-lap races, startup artwork and loading UI. Checked six racers in single-player and split-screen, plus clean installation and an upgrade from v2.3.0. Original supplied files remain unchanged.

On the recorded RTX A1000 laptop GPU at 1080p, the updated scenery reached the 120 FPS cap in Forward+ and about 113 FPS in separated split-screen Compatibility testing. These controlled comparisons use the same core with the old and new scenery. Full-precision HDR and baked lighting increase GPU memory use: the Forward+ split-screen monitor peaked at about 1.37 GB, versus 0.81 GB for the old scenery. Compatibility still has occasional streaming spikes; Forward+ is recommended. Results are hardware-specific. Full data and test limits are included in the evidence archive.

The HDR map contains authored linear sky/cloud radiance and explicit solar energy; it is not a measured photographic HDR capture. The track is adapted for racing and does not claim surveyed landmark placement.
