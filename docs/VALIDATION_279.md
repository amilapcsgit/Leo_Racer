# Leo Racer 2.7.9 — local review candidate

The 20-minute revision prioritizes the graphical loading-screen redesign, wheel animation and a runnable local build. This is a review candidate, not a certified production release.

## Verified

- Native loading UI: 3,927 checks passed, SDK removed, zero runtime or shutdown errors in this test. Transparent graphical device tiles occupy about 29% of the screen and use saved bindings. Rendered keyboard/controller/wheel PNGs replace the vector outline devices.
- Native wheel geometry: 43 checks passed on Duster 2014, Duster 2024 and Bigster. Every rolling pivot owns visible tire/rim mesh geometry; all wheels roll and only front wheels steer, in both directions. The compiler now resolves nested wheel groups before batching.
- Native gallery/audio: 80 checks passed. 23 genuine loading/home heroes include five new Sri Lankan locations; garage/workshop and billboard art is excluded. Original files remain preserved.
- Full UI/gauge suite before the final loading-art revision: 416 checks passed per renderer. Original analog RPM and digital km/h gauge geometry/font/visibility are identical in Chase, Ghost and Cockpit, solo and split.
- Cockpit Compatibility: 30 functional/pixel checks passed. Continuous swept clearances measured 25.849 mm Bigster, 25.823 mm Duster 2024, 21.243 mm Duster 2014, above the required 15 mm. Wheel-protection recompilation does not change the cockpit transform.
- Source preservation: nine synced originals and 191 inherited model/track/package files matched hashes.
- Menu music: original 90-second 128-BPM stereo/48-kHz composition; WAV -18 LUFS/-3.74 dBTP; Ogg -17.96 LUFS/-3.91 dBTP. Decoded duration, seam, finite samples and mono compatibility passed. Listening quality is not certified by numerical checks.
- .NET/native export was rebuilt using an isolated writable profile. The earlier missing-assembly export is archived as rejected and is not the delivered candidate. Native core check passed with SDK paths removed.

## Remaining limits

- Fresh native Kandy split-screen Forward+ Medium: p50 12.656 ms, p95 19.242 ms, p99 27.317 ms; preserved 2.7.8 comparison p95 14.693 ms. This misses the 16.7-ms target. Hiding roadside additions or restoring original road materials did not remove the regression. No locked-60-FPS claim.
- Seven renderer Texture RID shutdown warnings also reproduce on the preserved 2.7.8 native baseline. Application audio/resource leaks were fixed; these renderer warnings remain unresolved. Headless editor/plugin shutdown has additional pre-existing warnings.
- The extended native physics matrix is incomplete at this deadline. The installer compiled successfully; fresh-install/reinstall/uninstall verification has not been completed for this final revision.
- Physical gamepads/wheels, rumble/reconnect, TV scaling and hotplug remain unverified. No online publication was performed.

Raw reports, screenshots and logs are under build/qa279. Source branch: 2.7.9.
