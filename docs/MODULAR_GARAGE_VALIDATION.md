# v1.5.0 Modular Garage validation

Hardware: RTX A1000 laptop, 6 GB VRAM, Windows x64, Godot 4.7.2 .NET.

| Gate | Result |
|---|---|
| Catalog and independent GLB expansion | PASS: 96 combinations, 2,651 assertions |
| Wheel/driving/recovery | PASS: 11 behavioral checks |
| Presentation lifecycle / Reduced Motion | PASS: 24 checks |
| Garage layout and input | PASS: 56 checks at 720p, 1080p and 2560×1080 |
| Autonomous fleet | PASS: all 16 vehicles across three six-racer complete races |
| Astra preservation | PASS: 78 GLB/track/spec files; JSON compared structurally, GLBs byte-for-byte |
| Read-only supplied sources | PASS: all nine input hashes match |
| Warm full-race 1080p profile | 108.91 FPS average, p95 10.25 ms; 19,573 frames, 179.72 s |

The profile uses the demanding imported tuk-tuk and Mario/open-kart opponents,
approximately 2.19 GB VRAM. Results are measurements on this laptop, not a
guarantee for every PC. Machine-readable reports and matching captures are in
[qa-modular-garage](qa-modular-garage/).

The launcher is self-contained win-x64. Its offline self-test checks packaged
game presence. The NSIS 3.13 installer requests user privileges, creates current-user
shortcuts and removes only its enumerated owned files. It does not touch the Godot
user-data folder. Packages include the .NET runtime and Terrain3D native library.
See package-test.json for extracted rendering and install/upgrade/uninstall checks.

Known engine cleanup diagnostics: seven Vulkan texture RIDs on process exit;
the Terrain3D editor also reports one dummy texture, a CanvasItem and four ObjectDB
instances during headless editor shutdown. These are tracked separately from
runtime test failures. Compatibility uses simplified effects and terrain fallback.

# Reproduction and release

Run `tools/setup_windows.ps1`, then `tools/build_modular_release.ps1`,
`tools/build_launcher.ps1`, `python tools/package_modular.py`,
`tools/build_installer.ps1`, and `python tools/package_modular.py --checksums-only`.
Rokojori v0.6 is fetched from its official stable endpoint and checksum-verified;
its addon sources are ignored by Git. Supplied preparation inputs stay read-only.

GitHub branch pushes run the Windows build and behavioral gates. Only the separate
release job has contents-write permission. The first successful `ModularGarage`
build creates v1.5.0; subsequent pushes do not overwrite the stable release.
Version tags create their own releases. `-rc` tags remain prereleases. Initial
packages are unsigned. No certificate is stored or required in this repository.
