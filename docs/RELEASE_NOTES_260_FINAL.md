# Leo Racer 2.6.0

21 cars, three Sri Lankan tracks, a new Colombo showroom and clearer menus.

- Duster_My_2014 replaces the original Duster while retaining saved vehicle ID `duster`. Dacia Duster 2024 is car 21. Both include paint presets, working lamps and opening doors/trunk. Bigster remains the fallback.
- The garage has a full 3D car, skyline screen, colorful showroom lighting, seven-card carousel, compact driver portraits and vehicle actions. Selected and adjacent rides prepare in the background.
- Home uses three finished branded Colombo heroes featuring Bigster, white Duster 2014, or both cars. A new panoramic skyline preserves natural Lotus Tower proportions in the garage. Nine track-specific PNGs provide loading compositions. Loading artwork stays fixed during one operation and avoids immediate repeats.
- Menu controls use readable 24 px design text. Records have separate columns; Results Back/Escape/controller B restore normal menu state. Content remains reachable after a race, and the GLB/Workshop workflow remains available.
- New garage selections start front-on, then rotate after four seconds. Keep Racing dismisses the garage and resumes the existing race; unchanged selections retain the same car instance. Speed pullback and FOV changes are reduced to 10%, and the chase spring no longer accumulates speed-dependent translation lag.
- Glass solo instruments and matching compact split-screen instruments retain the cyan/gold identity. Dusk to Night joins Static lighting. Lotus Tower LEDs, fixture lighting, backlit ads, Kandy road art and eight Kandy boost pads improve night racing.
- Cosmetic suspension, boost feedback, drafting effects and prewarmed impact presentation preserve the existing physics/contact/damage implementation. Reduced Motion disables added autonomous presentation motion.
- Compiled Vehicle API 2/PCK content coexists with loose mods. SQLite work runs on a serialized worker. Earlier records remain separate; Kandy's changed course uses revision 2.

Download the portable Windows ZIP or installer. Keep the complete portable folder together; no development SDK or network is required. Forward+ is recommended; use **Play Compatibility.cmd** if Vulkan is unavailable. Graphics quality can be reduced in Settings.

Back up your previous game and custom content before upgrading. Extract the portable ZIP into a new folder. The installer preserves unrelated content and backs up modified managed files under `ContentBackups`. Settings and records retain their existing user-data location.

The contributor SDK, UI artwork/provenance, Duster asset packages, packed Blender masters, evidence and SHA256 checksums are separate downloads. Source-mod attribution and terms remain in each vehicle package; conversion credit is Amila Prasad Perera.

Performance targets are advisory for this release. Remaining cold-load/first-effect spikes and shutdown texture-resource warnings are documented in TEST_REPORT.md; this release does not claim all performance targets passed.
