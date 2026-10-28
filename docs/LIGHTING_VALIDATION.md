# Lighting local playtest checkpoint - acceptance incomplete

Base: `release/2.6.0`, commit `857918916a961009258fb91730153e2a67af7609`.

The independent content stage is `build/lighting-content/GameAssets`. The existing
`build/Preview-2.6.0`, Blender masters, downloaded source mod, and installed game
are not output targets. No public release has been published.

## Verified so far

- The original track collision shapes and world transforms match exactly: 84 in
  Colombo City and 2,049 in Kandy. Automatically named nodes receive serialized
  names; their collision data is unchanged.
- No new receiving mesh exceeds 32 m. Largest inspected spans are 28.86 m in
  Colombo and 27.64 m in Kandy.
- Fixture data recovers 197 existing Colombo lamp positions and 87 Kandy positions.
- World checks exercise Kandy's eight boost pads, seven road graphics, revision 2,
  both Dusters, continuous monotonic transition progress, photo freeze, static
  restoration, and Reduced Motion's static tower pattern.
- Initial Home prefetch checks prepare the selected car and both neighbors. The
  UI remains usable while preview resources load. Prepared assemblies are limited
  to three, with the existing estimated 512 MiB resource budget.

## Gates still open

The performance gates have **not passed**. The latest controlled Kandy Compatibility
split-screen Dusk to Night sample reports p95 31.223 ms, p99 35.589 ms, and worst
53.407 ms. A matched baseline rerun also slowed to p95 23.419 ms on this machine;
these measurements do not establish the original hardware target. The candidate
exceeds the required warmed p95 16.7 ms target. Diagnostic
runs with shortened sampling windows or GPU timestamps are not release evidence.

Prepared garage switches measured 9.9-11.6 ms in Forward+ and 10.2-11.4 ms
in Compatibility. UI entry was under 3 ms. Forward+ worst frame was 13.7 ms;
Compatibility recorded one 88.5 ms frame and does not pass the 50 ms limit.
A separate cold Forward+ selection took 1.10 s, with a 113.8 ms worst frame.

Latest completed world checks passed in both renderers (107 Forward+ checks,
91 Compatibility checks). Cold contact callbacks ranged up to 3.84 ms, exceeding
the 2 ms target; surrounding settled-scene worst frames measured approximately
21-24 ms. The most recent conservative damage-triangle rejection optimization
and warm-up camera alignment still require a fresh cold-contact measurement.

Content checks passed 449 checks per renderer, including 21 cars, both Dusters,
actions, lighting targets, and all six driver assemblies. Functional runtime
checks passed 17 checks per renderer. A functional PASS does not imply that
performance targets passed.

The user explicitly requested a separately named **local playable checkpoint**
before the photo-reference garage refactor. This overrides the earlier instruction
to wait for every performance gate before creating a build, for this checkpoint
only. It is not an accepted release. The existing preview and installed game are
not replaced. The new reference garage design has not been implemented here.

The final 24-case performance matrix, transition clips, full installer preservation
suite, and release acceptance remain incomplete. The checkpoint ZIP includes this
report and isolated-profile launchers. No public release is published.

## Evidence and reproduction

Evidence is written beneath `build/qa-lighting/`; accepted 2.6 evidence remains in
`build/qa260/`. Use `tools/qa_lighting.py` for independent presentation, world,
content, functional and native performance checks. The native harness is diagnostic
only, not a deliverable Windows export. The local checkpoint uses a fresh .NET
Windows export in build/LightingCheckpoint, independently assembled content,
and the built-in packaged smoke tests in both renderers.

Known shutdown warnings include leaked Texture RIDs and ObjectDB instances.
These remain open; they must not be read as a clean shutdown acceptance result.

Compiler: `tools/compile_lighting_tracks.gd`. Always restore the original track
manifests, routes and cell lists from the preserved 2.6 preview before compiling.
Do not feed a derivative pack back into its own compiler output namespace.

Godot documentation used for the implementation:

- [Per-mesh local-light limits](https://docs.godotengine.org/en/stable/classes/class_omnilight3d.html)
- [Pipeline compilation and Compatibility warm-up](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html)

The Colombo skyline was generated with the built-in image generation tool. The
saved asset and generation prompt are recorded in `assets/ui/provenance.json`.
