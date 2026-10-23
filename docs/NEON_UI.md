# Leo Racer 2.0.0 — Neon UI

The garage now uses a three-card driver carousel with two arrows and no scrolling. The center driver is selected immediately; neighboring portraits use perspective shading. Keyboard arrows, controller D-pad/stick, side-card clicks, and arrow buttons all select through the same component. Setup labels the originating player, and browsing P2 leaves P1 unchanged. The showroom retains its asynchronous preview generation guard, car controls, names, and orbit camera.

## Presentation components

- `LeoActionButton` owns activation and combines hover/focus into one active state. Its `LeoButtonFX` child animates an inner visual without moving the hit area. Feedback is connected before navigation callbacks. Per-instance ShaderMaterials prevent one button affecting another.
- `LeoUIEffects` owns the visible-screen effect clock and four pooled CPUParticles2D emitters in a persistent FeedbackLayer. Press bursts survive screen replacement. Hidden controls do not advance their shader clocks.
- `LeoDriverCarousel` emits `driver_selected(driver_id)` to the existing garage selection workflow. Six logical drivers share three visible positions; interrupted transitions retarget to the newest selection.
- `LeoBackdropFX` adds overscanned parallax and sparse ambient particles to Home. The frontend's backdrop and modal shield cover ultrawide viewports while interactive layout stays inside the existing safe area.
- `LeoTrackHologram` projects the actual route SVG with a small perspective tilt and offset echo. `LeoStatBar` redraws from tweened property setters rather than starting its redraw after the value tween.

| Effect | Defaults |
|---|---|
| Button focus | Inner scale 1.05, 150 ms cubic ease-out |
| Press | Scale 0.98 for 70 ms |
| Primary glow | Strength 1 → 2 over 150 ms, settling to 1.35 |
| Glint | 3 s period, 650 ms travel, width 0.045, brightness 0.45; unique phase and clock |
| Press burst | 18 stars, 400 ms, radial spread, 90–210 px/s, gold → cyan → transparent |
| Carousel | 220 ms; center 144×160, neighbors 72×104 at ±25° |
| Stats | 500 ms cubic ease-out from current value, fading white highlight |
| Route hologram | ±16° over a 10 s sine cycle |
| Home parallax | Background 8 px, decorative accent 16 px, 24 px overscan |

Reduced Motion stops scaling, carousel travel, showroom rotation, glints, particles, hologram tilt, and parallax. Static neon focus/selection, sounds, and short screen fades remain. The podium uses unshaded colored emissive rings and a procedural additive halo, with a 200 ms selection pulse.

## Loading and audio

`LeoLoadingBackdrops.begin_load(operation_id)` chooses a random starting day/night image per application launch and alternates for subsequent operations. Progress updates, failure retries, and the bootstrap/game handoff retain their operation's image. Existing artwork is reused: `assets/art/menu.png` and `assets/ui/art/home.png`. Both imported textures and their remaps are retained in the core PCK before external packs mount. A gradient shade and larger loading detail text keep both backgrounds readable.

The procedural sound synthesizer is vendored from [Game Menu Kit Lite](https://github.com/eXiForever/godot-game-menu-kit-lite) at commit `08ffb82a46c818962edd4b0e34d4c4b596629760`. Its MIT notice is in [GameMenuKitLite-MIT.txt](../licenses/GameMenuKitLite-MIT.txt). The integration uses its static synthesis functions through `LeoUIAudio`; it adds no plugin, autoload, settings file, or navigation owner. Original Leo neon shaders are independent of the kit.

Generated streams are cached during initialization. Four UI players share the existing UI bus; voice and music retain their own buses. Move cues are limited to 85 ms, with a short hush after opening/back navigation. Distinct carousel and preview cues complement select, open, Back, and unavailable sounds. The existing English spoken milestones remain available.

## Verification and release

Run `tools/check_ui.ps1` for the seven functional suites, including 51 new neon checks. Run `tests/neon_ui_test.gd` with `--visual-test` under each renderer for carousel, loading, Reduced Motion, and hologram captures; `tests/ui_visual_matrix.gd` covers the complete screen/resolution matrix. QA outputs go to ignored `build/qa-neon/` and `build/qa-ui/` folders.

`tests/neon_gpu_profile.gd` measures Home, Garage, and Track Selection at 1080p. It can load the verified 1.9 core PCK with `--main-pack` and mount its unchanged external packs using `--baseline-assets=<GameAssets folder>`, allowing the same engine/hardware/sample sequence to measure both versions. The compact result is in [qa-neon/validation.json](qa-neon/validation.json).

Build the release package with `tools/build_ui_release.ps1 -Version 2.0.0`, then run `tools/verify_ui_package.ps1 -Archive dist/LeoRacer-2.0.0-win64.zip`. The verifier checks both loading textures before content mounting, offline content, and exported menu/race smoke behavior with SDK paths removed. The installer verifier uses an isolated folder and skips real user-installation registration.

The published 1.9.0 release is the baseline. Version 2.0.0 is published from `neon_ui`; the 1.9.0 release remains available. Physical keyboard rollover, physical controller/wheel reconnect, and Leo's usability playtest still require the intended hardware and player.
