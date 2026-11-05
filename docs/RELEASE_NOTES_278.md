# Leo Racer 2.7.8 candidate

- Hardened the digital speed readout with a prewarmed bundled raster font, unclipped labels and local display diagnostics.
- New Graphics, Audio, Controls and Accessibility tabs. Added 720p/1080p/native rendering choices, timed display confirmation, AA/glow controls, optional world-only speed blur and Forward+ FSR 2 upscaling.
- Camera View button and remappable action: Chase, Ghost and reviewed Bigster Cockpit. Camera preferences are independent per player. Ghost hides your car only in your viewport.
- Reduced Motion retains gentle turn lean and braking/acceleration pitch while suppressing camera motion, impact jolts, bounce and motion blur.
- Reviewed two-part Bigster/Duster collision hulls, inelastic contact/sliding, per-tick vehicle-pair resolution and protection against moving-platform launch impulses and contact-driven checkpoint gains.
- Shared contact events drive material-specific effects, audio and rumble. Surface-aligned mesh skid marks work in both renderers; global effect budgets remain bounded.
- Existing settings, custom bindings, historical records, portable vehicle files and source assets are preserved.

## Controls and display

Press **C** or **right-stick click** to cycle cameras, or use the HUD button. Default look-back is now **V** or **left-stick click**. Shared-keyboard Player 2 uses **numpad 4** for camera view and **numpad 0** for look-back. Existing custom bindings are preserved; if a new default conflicts, bind Change Camera View in Controls.

Cockpit is enabled only for reviewed interiors, initially Bigster. Unsupported cars fall back to Chase while retaining your saved Cockpit preference. Orbit and automatic reverse camera remain Chase features; Ghost/Cockpit support held look-back.

In windowed mode, Resolution changes the window output size. Fullscreen keeps the monitor and HUD at native resolution and sets the 3D render target to the selected height. Upscaling further reduces internal 3D resolution. FSR 2 requires Forward+ and includes its own temporal anti-aliasing; the AA toggle controls MSAA. Compatibility uses native/bilinear scaling. Motion Blur is a restrained radial speed effect, off by default and suppressed by Reduced Motion. DLSS is not included.

New records use `distinct_v4+contact_v278_static` or `distinct_v4+contact_v278_dusk_night`, retaining the elevation suffix. The contact suffix avoids mixing results with the pre-existing historical `distinct_v4` namespace. Earlier 2.7.1 results remain accessible in Records filters. Camera and cosmetic choices do not change eligibility.

For speedometer investigation, start with `-- --hud-diagnostics`. The bounded log is `%APPDATA%\Godot\app_userdata\Leo Racer\speedometer-diagnostics.jsonl`; it records display/renderer and label state, with no account data. The intermittent original trigger and physical 4K-TV behavior require external confirmation.

Run `LeoRacer.exe` normally or `Play Compatibility.cmd`. Keep the whole portable folder together. Fully offline; no SDK or account required. See TEST_REPORT.md for measured validation and hardware limitations.
