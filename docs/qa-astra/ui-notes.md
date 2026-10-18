# Astra UI and arcade audio

The garage uses a five-card driver row and a three-by-three vehicle grid inside the left 668 × 900 design area. All 45 combinations remain visible without scrolling. Selection preserves keyboard/controller focus; explicit neighbors connect every card, Race, and Back. The right area retains the live model preview, selected names, combination count, and vehicle stats.

The race HUD uses circuit-provided sector names, measured speed, lap progress, and a look-ahead corner prompt. The minimap fits the actual circuit bounds through one shared projection for road geometry and racer markers. Existing neon instruments and liquid nitro remain. Nitro-full and drift-charge transitions play a single ready cue and show a short callout when no other announcement is active. Animation time, instrument smoothing, selection feedback, and map pulse freeze on pause. Reduced Motion suppresses pulsing and scaling.

## Integration

- `hud.play_arcade_cue(key)` accepts `select`, `ready`, `lap`, `bus_horn`, and `tuk_horn`. These use an independent audio player and never replace gameplay's shared click stream. Selection and charge-ready are already connected in the HUD; gameplay owns lap and horn triggers.
- `LeoTelemetry.map_transform(points, area)` returns a `Transform2D` shared by the map line and markers.
- HUD reads `circuit.sector_name(s)`, `circuit.direction(s)`, `circuit.length`, and `player.last_s`. It does not change vehicle or track behavior.
- Regenerate all five original PCM WAVs with `python tools/make_astra_audio.py`. The generator uses deterministic standard-library synthesis, no external samples, and prints durations, level checks, and SHA256 hashes.

## Focused validation

- Both HUD scripts passed Godot 4.7.2 .NET `--check-only` parsing.
- Run the committed `tools/astra_ui_test.gd` with Godot `--headless --path . --script tools/astra_ui_test.gd`. **790 assertions passed** at 1280 × 720, 1920 × 1080, and 2560 × 1080. Every focus neighbor resolves, garage cards remain disjoint, and all 45 driver/vehicle combinations retain focus after selection. The centered design canvas fits each viewport; pause freezes the UI clock and Reduced Motion suppresses card scaling. Restart clears F8 photo mode, previous callouts and smoothed instrument values and restores the race HUD. Both the complete 953-point Astra route and a 1.5 km synthetic extent fit the minimap. Measured-speed lines begin above 150 km/h, reach full strength at 180 km/h, combine with boost using the greater intensity, and stop for inactive racers or Reduced Motion. Results are recorded in `ui-layout.json`.
- Audio outputs are 44.1 kHz, 16-bit mono PCM; durations are 0.20 s selection, 0.92 s lap, 0.52 s ready, 0.72 s bus horn, and 0.43 s tuk-tuk horn. Peaks remain at 0.76–0.84 full scale.
- The focused UI harness does not prove full-race performance or final visual composition; those are covered by the integrated Astra validation.

## Final presentation captures

`tools/astra_capture.gd` produced **39 fresh 1920 × 1080 Forward+ captures** on the RTX A1000 with Godot 4.7.2 .NET. `captures/capture-manifest.json` records the renderer, GPU, camera framing, selected driver/vehicle, HUD state and output dimensions. The tour includes all nine garage previews, menu/guide/settings, countdown, five route sectors, the route overview, front and reverse advertisements, national flag, seven placed road decals, nitro and Reduced Motion, speed lines, drift, pause/results, and the racing tuk-tuk and bus.

Visual inspection confirmed the dark telemetry backing remains readable against the sunset, countdown reads 3, results rows and times fit, road artwork is correctly oriented, and advertisements retain saturated color on both faces. Nitro exhaust remains visible under Reduced Motion while screen-edge motion lines disappear. The final road surface has no earlier hash-grid seams. The captures stage presentation states and freeze physical simulation for matching framing; the full-race and package tests establish gameplay and performance separately.
