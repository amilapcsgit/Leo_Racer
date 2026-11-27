# Leo Racer 2.7.9 validation

Release assembled on 7 November 2026. The owner accepted the mirrors and explicitly requested immediate publication, stopping further testing. This release does not claim exhaustive certification or locked 60 FPS.

## Completed checks

- Clean Compatibility mirror coverage: **107 checks passed**, all three cockpits, side-look, hidden/offscreen inactivity, both players and split-screen night. Thirteen actual changed-texture samples measured **29.96–30.37 fresh images/second**. Shared deadlines retain fractional time, avoid catch-up bursts and stagger players. Solo 128×64/80 m; split 64×32/60 m.
- Native core: **54 checks passed**, SDK removed, zero application or shutdown errors after the bootstrap audio handoff fix. The subsequent native diagnostic-adapter refresh changes test adaptation, not production gameplay. The native benchmark reached gameplay but was stopped before timing results.
- Audio state/playlist: **36 checks passed**, persistent singleton, continuous menu/loading/countdown intro, Kandy/coastal GO choices, six-track exhaustion without immediate repeats, automatic end-of-track crossfade, handoff offsets, pause/mute, announcer ducking and stream release.
- Game Logic: **41 checks passed**, migrated/default OFF, opt-in Bigster AI, human selection, next-restart snapshots and empty-content behavior.
- Existing unit regression: **58 checks passed**. Legacy record compatibility, input, core, ranking and race regressions passed during the isolated export pipeline.
- Approved native loading controls: **3,927 checks passed**. Graphical PNG guides occupy about 29% of the screen and use saved bindings. The previous complete UI suite passed 416 checks per renderer; the original analog RPM/digital km/h gauge remains consistent across cameras and players.
- Cockpits: **30 checks passed per renderer**, with 42 steering/cabin stills and changed instrument pixels. Continuous swept clearance: 25.849 mm Bigster, 25.823 mm Duster 2024, 21.243 mm Duster My 2014. Final in-car gear-text readability adjustment was parser checked after those captures.
- Native wheels: **43 checks passed**, tire/rim rolling and front steering both ways on all three cars. Original models and track packs remain unchanged.
- Gallery: 23 eligible loading/home heroes, including five labeled AI-generated Sri Lankan illustrations. Garage/workshop and billboard art excluded. Earlier gallery checks passed; final gallery-only extraction has not been rerun after obsolete audio assertions were separated.
- Four supplied recordings: non-destructive 48 kHz stereo Ogg conversion, original hashes unchanged, decoded loudness −18.07 to −18.10 LUFS and peaks −3.64 to −4.72 dBTP. Island Music: −17.94 LUFS/−2.19 dBTP. Conditional circular seam preparation and decoded finite-sample/boundary checks passed, maximum seam step 0.004932. Ceylon Afterglow remains in the pool and its WAV master is preserved. Numerical checks do not certify subjective listening quality.
- Preservation: nine synced originals and 191 inherited model/track/package files matched hashes. README includes captioned actual cockpits, exterior steering views, split-screen gameplay and approved loading interfaces.

## Known limits and unfinished checks

- Earlier native Kandy split-screen Forward+ Medium: p50 **12.656 ms**, p95 **19.242 ms**, p99 **27.317 ms**, RTX A1000 6 GB Laptop GPU. This misses 16.7 ms. Prior scenery/material isolation did not remove that shortfall. The fresh 2.7.9 baseline comparison and native mirror off/on benchmark were stopped at the owner's request; no fresh performance or ≤10% regression claim is made.
- Forward+ shutdown reports seven Texture RIDs; Compatibility reports two 349,524-byte GL texture leaks. Both reproduce on the previous native baseline. Clean mirror testing had no mirror/script/audio runtime errors. Editor/plugin cleanup warnings are separate.
- Extended native physics matrix remains incomplete. Final fresh-install, actual 2.7.8→2.7.9 upgrade, seeded saved-profile preservation, uninstall-preservation and portable-extraction checks were not completed after the owner stopped testing. Prior-version checks do not certify this payload.
- Physical controller/wheel input, hotplug, rumble, TV scaling and every renderer/lighting/device combination remain unverified. No public Vehicle API or save-database migration is introduced.

Checksums, provenance, raw reports and selected before/after captures accompany the release. Exploratory/interrupted logs are historical evidence, not passing acceptance results. The tag identifies committed source; release-build.json identifies the shipped core hash.
