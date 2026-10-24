# Leo Racer 2.2.0 — Loose content and contributor tools

Vehicles and tracks can now be added or updated independently of the executable. The full download contains all sixteen shipped vehicles as visible GLB/JSON folders under GameAssets/vehicles; the optional development profile contains only Bigster and Duster.

- Vehicle API 1 and Track API 2, automatic discovery, readable validation errors and disposable content-hashed caches in user data.
- Content → Vehicles: configure model orientation, wheels/pivots, collision, all six driver fits and camera; privately test drive before exporting a portable folder.
- Refresh Content shows scan progress, updates the roster in place and runs automatically when leaving the workshop. Refreshing is blocked during races.
- Contributor SDK: standalone Godot track project with route, grid, recovery, collision and streaming-cell export helpers, plus editor texture optimization.
- Separate core, vehicle, track and distribution build targets. Custom/modified content is unranked; existing official records and settings are preserved.
- Neon UI, both tracks, single-player/split-screen, arcade handling and Bigster scale/wheel centers retained.

Install **LeoRacer-Setup-2.2.0.exe** or extract the complete **LeoRacer-2.2.0-win64.zip**. The main installer/portable archive includes all sixteen cars. **LeoRacer-2.2.0-dev-win64.zip** is the two-car profile. Keep the entire folder together; no editor, .NET SDK or network connection is needed. **LeoRacer-Contributor-SDK.zip** is for authors. Verify downloads with **SHA256SUMS-2.2.0.txt**.

Validation: sixteen cars × six drivers (1,205 checks), independent component hashes, offline content additions, cache deletion/reuse, malformed content, both tracks, input/ranking/collision regressions and installer preservation. Six-racer 1080p split-screen on RTX A1000 averaged 119.9 FPS in Vulkan and 119.4 FPS in Compatibility; p95 frame times improved versus the v2.1 loading-path baseline. Isolated 38 ms Vulkan / 71 ms Compatibility frames and existing Godot teardown warnings remain. Arbitrary contributor models still need optimization; physical Logitech-wheel testing remains unavailable.

See docs/MODULARITY_VALIDATION.md and sdk/README.md for measurements and compatibility requirements.

---

# Leo Racer 2.1.0 — Colombo City

The 5.5 km Colombo City Grand Prix now has fuller streets and a convincing tropical coast, with complete buildings assembled from the modular kit instead of isolated building parts.

- Twelve building recipes form 1,265 shops, terraces, corner buildings and small apartments across four districts, with secondary streets, props and varied materials.
- Shaped coastal terrain, seawall, shoreline and separate ocean/lake water; Galle Face Green, Lotus Tower and existing custom landmarks preserved.
- Bright tropical midday, a generated distant skyline panorama and separately authored floating-point HDR illumination.
- Scenery streaming considers both players; nearby detail and inexpensive distant silhouettes retain city depth.
- Both tracks, the neon UI, single-player and split-screen, all vehicles, Bigster scale/wheel pivots, race geometry and existing rankings remain intact.

Download **LeoRacer-Setup-2.1.0.exe** to install, or extract the complete **LeoRacer-2.1.0-win64.zip** and run LeoRacer.exe. Keep GameAssets and the other supplied folders together. No Godot, .NET SDK or network connection is required. Use Play Compatibility.cmd for OpenGL. Verify files with SHA256SUMS-2.1.0.txt. Existing settings and rankings are preserved.

Validation includes three-lap races on both tracks, two-player finishing, input/ranking regressions, twelve Dacia driver fits, Bigster wheel checks, twelve fixed-location comparisons and separated-player streaming. The track has also been manually playtested. Six-racer 1080p split-screen on RTX A1000 measured approximately 120 FPS in Forward+ and Compatibility; an isolated 75 ms Compatibility frame and brief loading insertion spikes remain. Existing Godot teardown diagnostics persist. Physical Logitech wheel compatibility remains unverified.

Asset attribution, licenses and generated-image provenance ship with GameAssets. Detailed measurements and captures: docs/COLOMBO_VISUALS.md and docs/qa-colombo-visuals/.
