# Leo Racer 2.3.0 — Kandy and selectable cars

- Three offline circuits: Astra Lotus Coast, Colombo City and Kandy Lake.
- Updated Bigster with headlights, brake lamps and preserved wheel pivots.
- Original 16 vehicles included by default; 32 additional imported cars individually selectable during installation. Optional cars start unchecked.
- Full offline installer: no account, network connection or installation downloads needed. All vehicles remain loose folders under GameAssets/vehicles.
- Portable users can copy their chosen car folders from the Additional Cars ZIP. Imported cars have rotating/steering wheels and blue boost jets, no visible driver, and remain modded/unranked.
- Settings, rankings and user-added content are retained. Re-running setup adds cars; deselecting an installed car does not remove it. Modified files replaced during updates are backed up under ContentBackups with an index; modified/unowned files survive uninstall.

## Downloads

Choose LeoRacer-Setup-2.3.0.exe for the complete installer, or LeoRacer-2.3.0-win64.zip for the default portable game. LeoRacer-AdditionalCars-2.3.0.zip contains optional vehicle folders. The Kandy track is also provided separately for compatible 2.3 cores. Verify files with SHA256SUMS.txt; exact installed and download sizes accompany the release.

## Build and validation notes

This release uses Godot 4.7.2's checked runtime, matching the tested development build. The unchecked optimized runtime was rejected after native shutdown failures during Colombo regression testing. No remote debugger or network service is enabled.

The Kandy scenery benchmark on RTX A1000 previously averaged 112.7 FPS Forward+ and 80.0 FPS Compatibility at 1080p split screen. Compatibility exhibited a 190ms frame spike and remains the fallback renderer. Final package validation is recorded in the source release report.

Mahaweli Seya is artistically relocated near Kandy's starting area; this circuit is an adaptation, not an exact public-road reconstruction. Imported-car redistribution permission was confirmed by the supplier; individual model licenses and attribution remain in each vehicle folder and ATTRIBUTION-2.3.0.txt.
