# Leo Racer 2.3.2 — Windows test candidate

Implemented Bigster's automatic brake/reverse lamps, switchable headlights and
sliding sunroof; reusable vehicle feature metadata/Workshop authoring; two
assignable action slots; automatic reverse view, held Look Back and mouse/right-
stick orbit. The build contains the original 16 default cars and three tracks.
It is a local test candidate, not a new public GitHub release.

This revision includes Bigster 1.2.1: narrow red Y-shaped upper LED rails,
a separate white reversing lamp in the rear bumper, and illuminated main front
optical cells alongside the signature strips. See LIGHTING_CORRECTION.md and
the close views in lamps-forward/ and lamps-compatibility/. The prior package's
upper-cluster reverse bindings were incorrect and have been removed.

## Verified

- 53 focused feature checks: six actual physics light-state cases, independent
  cars/materials, roof reversal/recovery, embedded animation clips, malformed
  metadata, legacy profile support, controller profiles and mouse ownership.
  Added optical-group checks ensure the reverse target/anchor is in the bumper,
  both main headlamp cells and signatures illuminate, and only inset red Y rails
  emit in the upper rear clusters.
- 69 packaged camera/command checks in each renderer, across all three tracks
  in single-player and split-screen, including separated players and wall tests.
- Six Windows three-lap race checks: six racers, all three tracks,
  single-player and split-screen. All passed.
- Existing input (35), Workshop (22), presentation (21), local race (21) checks;
  codec round-trip for 16 cars. All passed.
- Installed-content validation: all 48 cars import, 16 remain official, optional
  imported cars remain unranked. No unavailable vehicles or missing wheels.
- Startup/loading punctuation audit passed. Bigster handling, wheels, collision,
  normalization and driver fits match 2.3.1. All track-package files match 2.3.1.
- Screenshots show independent brake/reverse/headlights, open/closed roofs, and
  reverse views in Forward+ and Compatibility. Raw logs and JSON are included.

## Observed performance

NVIDIA RTX A1000 6GB Laptop GPU; Kandy at 1920×1080, two separated local players,
six racers, 30-second measurement after warm-up. Each cell is 2.3.1 → 2.3.2.
These are local observations, not a controlled hardware benchmark.
The latest Forward+ run included a 146.6 ms maximum frame despite its 14.3 ms
p95; the candidate does not claim that streaming or frame-time spikes are solved.

| Renderer | FPS | p95 frame ms | Peak static MB | Peak VRAM MB | Maximum frame ms |
|---|---:|---:|---:|---:|---:|
| forward | 93.1 → 95.3 | 14.63 → 14.31 | 231.44 → 226.41 | 1483.8 → 1483.8 | 19.9 → 146.6 |
| compatibility | 58.4 → 62.4 | 23.16 → 23.79 | 156.17 → 157.15 | 837.8 → 831.5 | 297.7 → 84.7 |

Both versions emit Godot renderer/ObjectDB cleanup diagnostics at shutdown,
particularly Compatibility texture leaks; the repeated track-change camera
stress test also reports unreleased render resources at exit. Functional checks
passed and processes exited normally. These warnings are retained in the logs;
this candidate does not claim warning-free renderer teardown. Physical
controller/wheel hardware testing remains unverified; automated checks inject
device events and exercise ownership, rebinding and disconnection behavior.

## Use

Extract the complete portable ZIP into its own folder and run LeoRacer.exe.
L toggles headlights, O toggles Bigster's sunroof, C holds Look Back, and right-
mouse drag orbits. Gamepad defaults: D-pad left/up/down for lights/actions 1/2,
right-stick click for Look Back, right stick for orbit. Change them in Controls.
Bigster Action 2 is intentionally unassigned. The standalone Bigster package
requires core 2.3.2. Content → Vehicles → Set Up Vehicle edits other cars' rigs.

Original downloads, synced sources, the installed game, settings and records
were not edited. Diagnostic profiles live under build/vehicle232/profiles.
The source working tree and its base commit are recorded in source-fingerprints.
See VEHICLE_FEATURES.md beside this report for the authoring/API guide.

The portable ZIP was extracted and its member hashes checked against the build.
Content, boot artwork and all 69 packaged camera/command assertions passed from
that extraction with .NET SDK paths removed and DOTNET_ROOT pointing to an empty
location. The included Windows runtime is self-contained.
