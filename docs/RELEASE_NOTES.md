# Leo Racer 1.9.0 — Street Racing

Get racing with **Go Race → Start Race**. One setup screen brings together your track, ride, players, and controls.

- **Two players, one keyboard:** P1 uses WASD, Space and Left Shift; P2 uses arrows, Right Ctrl and Right Shift. Remapping and a simultaneous controls tester are included.
- **Automatic controls:** available mapped controllers are assigned first, with keyboard fallback. Device owners remain fixed during a race; reconnect, then choose Keep Racing.
- **A cohesive new interface:** cinematic Colombo artwork, illustrated track cards, a live 3D garage, glass dialogs, compact solo/split-screen HUDs, and keyboard/controller navigation.
- **Arcade personality:** animated focus, musical menu cues, and offline English cheers, with separate audio controls and Reduced Motion.
- Both existing tracks, six drivers, sixteen vehicles, race rules, settings, and offline rankings are retained.

Download **LeoRacer-Setup-1.9.0.exe** to install or extract the complete **LeoRacer-1.9.0-win64.zip** and run **LeoRacer.exe**. Use **Play Compatibility.cmd** for OpenGL. No SDK or network connection is required. SHA-256 checksums accompany the downloads.

Validation: 160 functional assertions, 78 rendered captures across three resolutions and two renderers, full-race integration, offline exported-package checks, and isolated installer verification. The measured pause UI increase was 0.492 ms on an RTX A1000 at 1080p. See `docs/UI_REFRESH.md` and `docs/qa-ui/validation.json` for evidence and scope.

Included voice lines use offline English speech synthesis. Leo's usability playtest, target-keyboard rollover, and physical controller/wheel reconnect checks remain pending. Wheel force feedback is not included. This package retains the checked Godot template used for the verified 1.8 release.
