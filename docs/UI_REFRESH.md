# Leo Racer 1.9.0 — Street Racing

Based on release/1.8.0, commit `529cb55`. Release branch: `release/1.9.0`.

## Play

Use `dist/LeoRacer-1.9.0-win64.zip`, extract the entire folder, then run `LeoRacer.exe`. The release includes its .NET runtime and content packs. `Play Compatibility.cmd` selects OpenGL.

Home → **Go Race** → choose one or two players → **Start Race**. Names, cars, and track selections remain optional changes. Both players share one Start action.

Auto fills mapped controllers in runtime-ID order, then uses keyboard controls. Existing explicit assignments take priority. Controllers keep their owners during a race. Reconnect or choose Controls, then choose **Keep Racing**.

| Shared keyboard | Player 1 | Player 2 |
|---|---|---|
| Drive | WASD | Arrows |
| Drift | Space | Right Ctrl |
| Nitro | Left Shift | Right Shift |
| Recover | R | Backspace |
| Horn | H | Enter |
| Pause | Esc / P | Esc / P |
| Hide own HUD | F8 | F9 |

Keyboard rollover depends on hardware. Controls → Test Controls lights both players' actions. Rebinding detects conflicts and supports a safe swap. Solo bindings and custom actions are retained when entering and leaving shared mode.

## Implementation

- `LeoFrontend` owns screen navigation, dialog callers, focus suspension/restoration, directional neighbors, and action dispatch. Gameplay state remains in the existing game controller.
- Reusable Godot scenes provide ActionButton, PlayerCard, TrackCard, DeviceChip, InputGlyph, StatBar, and ConfirmationDialog. A single theme covers menus and native settings/binding controls.
- Dialogs use a screen copy and mipmapped blur in Forward+; Compatibility uses a dimmed backdrop. Long dialogs scroll rather than pushing actions off-screen.
- The existing live garage keeps its asynchronous model-selection guard, orbit camera, and driver seating. Hexagonal portraits and segmented statistics use real balanced race rules.
- Solo and split-screen share `LeoPlayerHUD`. Track information and driving tips are temporary; nitro cues use actual bindings.
- Input profiles are versioned and retain per-device bindings, solo keyboard bindings, modifier location, explicit/Auto preference, calibration, and ownership identity.
- Music, Effects, UI, and Voice have separate buses. Voice has its own enable toggle and cooldown. Reduced Motion removes moving focus effects and particles.
- The boot illustration and imported texture stay in the core pack. Other artwork and UI audio ship in the existing content-pack structure.

## Artwork and audio

Five original backgrounds were generated with the built-in image-generation tool: Home, Garage, Astra Coast, Colombo City, and Loading. Functional labels and controls remain native UI. Editable SVGs provide icons, portrait frames, nitro segments, particles, and route outlines derived from the shipped routes.

The exact prompts, provenance, voice source, and font reference are in [assets/ui/provenance.json](../assets/ui/provenance.json). Barlow Condensed Bold Italic uses the existing Barlow OFL notice.

The four bundled English cheers are **offline synthesized speech using Microsoft Zira**, not commissioned human recordings. Replace `assets/audio/ui/voice_{race,ready,choice,finish}.wav` with final recordings without changing code. The game does not need a speech service or network connection.

## Validation

Run `tools/check_ui.ps1` for the input, frontend, local race, ranking, and presentation suites. QA reports and screenshots are written under `build/qa-ui`.

The six functional suites pass 160 assertions. Rendered frontend checks cover 13 screen states at 1280×720, 1920×1080, and 2560×1080 in both Forward+ and OpenGL Compatibility: 78 captures. Run `tools/check_ui.ps1 -Visual` to recreate them. The checks exercise modal focus, per-player garage selection, track success/failure, pause-event isolation, returning to setup, solo HUD, and split-screen start.

Additional full-race integration and Colombo race tests completed three ordered laps for both humans and all four AI. Source tests using the dummy renderer may print resource-teardown warnings; inspect the JSON assertions and rendered checks separately from those diagnostics.

The Forward+ GPU profile at 1920×1080 on an NVIDIA RTX A1000 measured 90 frames after 30 warmup frames of the same frozen scene:

| Scene | Median GPU time |
|---|---:|
| Without UI | 6.922 ms |
| With compact HUD | 6.941 ms |
| With frosted pause menu | 7.414 ms |

Measured increases were **0.019 ms** for HUD and **0.492 ms** for pause, below the 2 ms target. This is one machine and scene, not a performance guarantee for every PC.

A compact checked report is saved in [qa-ui/validation.json](qa-ui/validation.json). Run `tools/verify_ui_package.ps1` to extract and validate the ZIP with the SDK removed from PATH. Version 1.9.0 also passed isolated installer installation, offline content/menu checks, and uninstallation. GitHub Actions rebuilds and checks the published packages; their download hashes are in the release SHA256SUMS file.

The exported executable supports `--headless -- --ui-smoke-test` to check packaged artwork, voice files, setup, dialogs, split-screen, pause/resume, and solo HUD without the SDK.

## Build and remaining hands-on checks

Run `tools/build_ui_release.ps1` with the repository's Python/.NET setup. It exports to `build/UIRefresh`, verifies category packs, and creates the versioned release ZIP. The export helper can temporarily disable editor plugins and restores `project.godot` byte-for-byte in `finally`; export temp and editor data stay in the workspace.

Still required:
- Leo's hands-on usability playtest.
- Physical rollover testing on the intended shared keyboard.
- Physical unplug/replug and identical-controller ownership checks with the intended controllers/wheel.
- Commissioned human voice recordings, if preferred over the included synthesized cheers.
