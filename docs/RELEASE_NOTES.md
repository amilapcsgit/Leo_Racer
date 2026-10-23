# Leo Racer 2.0.0 — Neon UI

The Pit Shop now features a dimensional six-driver carousel with complete names, responsive arrows, keyboard/controller navigation, and independent Player 1/Player 2 selection. Cyan and gold podium lighting celebrates each completed live preview.

- Reactive neon buttons with glass glints, focus animation, and short star bursts.
- Animated segmented vehicle statistics and holographic track outlines.
- Restrained Home parallax and ambient lights; Reduced Motion keeps selection clear without moving effects.
- Alternating daytime/nighttime loading art, available offline before asset packs mount.
- Cached procedural UI sounds with four playback voices; existing voice and volume settings retained.
- Existing Go Race flow, shared-keyboard multiplayer, controller assignments, saves, cars, tracks, and record rules preserved.

Download the Windows installer or extract the complete portable ZIP. No Godot, .NET SDK, or internet connection is required. Use Play Compatibility.cmd when Vulkan is unavailable. Verify downloads with SHA256SUMS-2.0.0.txt.

Validation: 211 functional checks and 122 rendered captures across Forward+ and Compatibility at 720p, 1080p, and ultrawide. Same-hardware 1080p GPU measurements added at most 0.063 ms across the measured menu screens versus 1.9.0. Offline ZIP and isolated installer checks cover boot artwork, content mounting, and runtime smoke tests. Full details: docs/qa-neon/validation.json.

Physical keyboard rollover, physical controller/wheel reconnection, and Leo's usability playtest remain hands-on checks. Existing engine teardown texture/RID diagnostics remain; final automated checks found no script, shader, or assertion failures.

Includes MIT-licensed sound synthesis from Game Menu Kit Lite, pinned to 08ffb82a46c818962edd4b0e34d4c4b596629760. Its license is retained in licenses/GameMenuKitLite-MIT.txt.
