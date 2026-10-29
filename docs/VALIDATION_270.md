# Leo Racer 2.7 Ultra validation

Candidate validation is in progress. This document is updated with final exported-build, installer and GPU evidence before publication; it does not claim those pending checks passed.

Hardware used for local rendered checks: Windows, NVIDIA RTX A1000 6 GB Laptop GPU, NVIDIA driver 566.14. Engine: Godot 4.7.2 .NET. Test profiles and installation targets are isolated from the player's settings and installed 2.6 game.

## Completed source checks

- All 21 cars have renderer-specific transparent hero images and cropped thumbnails: 84 RGBA PNGs. Alpha and framing validation passed. Official vehicle packages and source models were not modified.
- Core race configuration, lap-separated records, haptic envelopes and same-name controller assignment/reconnect tests passed. The test report records the current assertion count.
- Legacy SQLite fixtures passed through the actual C# worker. Existing timestamps and result values remained unchanged; a simulated 2.6 writer could still add sessions, which 2.7 subsequently interpreted as three laps. The database schema version remains 1.
- Existing input, ranking and multiplayer suites passed after explicit content staging. The multiplayer fixture verifies a genuinely different P2 vehicle during a pause swap. Graceful preparation shutdown replaced unsafe test teardown.
- The production-controller physics matrix passed 2,228 checks. All six racers completed 1, 3 and 10 laps on Astra Coast (1,905 m), Colombo City (5,500 m), and Kandy Lake (2,828 m), reaching gates 9, 25 and 81. The matrix uses actual track collision and vehicle dimensions, omitting rendering/audio for repeated physics runs. Stationary, drop, recovery, normal-speed and boost checks cover all 21 cars.
- Rendered UI checks covered 1280×720, 1920×1080, 2560×1440 and 2560×1080 in Forward+ and Compatibility. The broader pointer/keyboard/controller navigation, modal restoration and font-size suite is recorded separately. Leaderboard screenshots use isolated fixture data, not the user's personal records.

## Pending release gates

Native exported checks, clean portable extraction, installer/reinstall/uninstall preservation, matched 2.6/2.7 GPU benchmarks, and final artifact hash verification are pending at this candidate stage.

Performance goals are measured independently: preview UI ≤250 ms, selected cold preview ≤3,000 ms, warm preview ≤250 ms, sampled garage frames ≤50 ms, race p95 ≤16.7 ms, and first-contact callback ≤2 ms. Misses are reported explicitly; functional PASS does not imply a universal 60 FPS claim.

## Hardware and engine limitations

Godot currently detects no connected gamepads. Twin-pad assignment and rumble envelopes are tested with injected events/output; physical two-Xbox identification, wireless reconnect and sensation remain unverified until hardware is available. Wheel force feedback is outside this release.

The 2.6 baseline reported shutdown texture/RID warnings and occasional cold-load/streaming spikes. Final 2.7 process logs retain and classify any remaining warnings rather than hiding them. Renderer differences and lower graphics quality remain supported.

Full machine-readable results and screenshots accompany the evidence archive. This report is completed before the public release is promoted.
