# Leo Racer: offline development roadmap

The custom-car milestone comes first: reliable Content navigation, an offline
GLB workshop, four confirmed rotating wheels, boost effects and portable folders.
Distribute and verify that checkpoint before expanding the game architecture.

## Follow-up checkpoints

1. **Content quality and authoring.** Add measured triangle/material/texture
   budgets, optional offline LOD and texture processing, and script-free track
   validation. Keep original GLBs authoritative. Reload authoring previews safely;
   never replace resources underneath an active race. Ship tools and all required
   dependencies locally, with content ZIPs and checksums for manual sharing.
2. **Rendering and surfaces.** Improve material consistency, daylight, road
   detail and skyline transitions first. Add optional wetness, reflections and
   weather quality presets only after separate Forward+ and Compatibility
   measurements. Retain the existing lightweight presets and split-screen support.
3. **Driving feel.** Prototype four-point suspension and chassis feedback as an
   opt-in experimental profile. Preserve current arcade physics as the default;
   changed physics and surfaces make races unranked. Keep old records intact.
   Wheel force feedback requires a local platform bridge and real hardware tests
   before being described as supported.
4. **Audio and local progression.** Add licensed RPM/load sample layers, local
   reverb zones and sound budgets. Optional local career progress uses the existing
   offline save location; it must not alter or merge official race records.

## Acceptance gates

Every checkpoint needs extracted offline-package testing, both tracks, six racers,
single-player and separated split-screen cameras, unchanged Bigster pivots, and
rankings preservation. Report cold/warm loading, p50/p95/p99 frame times, memory
and installed/download sizes separately. Target 60 FPS at 1080p on the RTX A1000;
do not present performance budgets as achieved without measurements.

The runtime and contributor workflow remain fully offline. Do not add accounts,
telemetry uploads, matchmaking, network multiplayer, remote leaderboards, live
downloads or a publishing service. Community content moves through local folders
and independently distributed archives. Source attribution links are documentation,
not a required connection at launch or during play.
