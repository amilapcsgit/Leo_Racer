# Leo Racer 2.4.1

Distinct cars, smarter fair rivals, reliable races, and restored instruments.

- Ordered checkpoint validation and recovery preserve laps and keep late starts and exploration recoverable. Each local player finishes independently; no forced late-finish deadline.
- Occupied-controller selection reassigns the other player and retains usable Back navigation.
- The detailed solo HUD returns, alongside compact independent split-screen instruments.
- Shared performance profiles, realistic runtime sizes, and selective PBR repairs. Bigster is restored to 100% size with original driving coefficients and professional finish preserved.
- Spring camera, Reduced Motion, Low/Medium/High quality presets, Compatibility support, and layered RPM/load engine, tire and wind audio.
- New `distinct_v3` records; older rulesets remain legacy entries.

## Downloads

`LeoRacer-Setup.exe` and `LeoRacer-2.4.1-win64.zip` include **16 official cars and all three tracks**. The installer allows track selection. Private imported models are not distributed. Existing user-added packages and saves remain supported. No account, network, Godot installation or .NET SDK is needed. Extract the whole portable ZIP; run `LeoRacer.exe`, or `Play Compatibility.cmd` where needed.

## Validation

The exact tested core is preserved. Prior acceptance includes 144 clean laps, 180/180 seeded AI finishes, 600 identical Bigster manual-input ticks, and camera/material/HUD checks across both renderers. RTX A1000 warmed 1080p Medium p95: Forward+ 10.787 ms, Compatibility 13.266 ms. See TEST_REPORT.md for methodology, raw-result references and limits; PUBLIC_SMOKE.json covers the official-only release package.

Two isolated native startup stalls during validation passed fresh-profile retries; the cause remains unconfirmed. Engine/addon shutdown warnings remain. Physical multi-controller hardware and speaker listening were not independently verified. The user tested the local candidate before authorizing this release.

README images include untouched in-game captures and one clearly labelled AI-enhanced promotional image; its lighting/sky are not gameplay evidence.
