# local2player recovery journal

Base: published v1.6.0, 8654b6ecf5026ecff3049eb95d04e9987f75eb04.
Stable release and read-only sources must remain unchanged.

## Approved decisions

- Two local humans and four AI, three laps. Vertical divider: P1 left, P2 right.
- One shared physics world, independent input, cameras, HUDs and human race statistics.
- One keyboard player maximum; Xbox controllers and generic joystick/wheel profiles.
- Remapping and steering/pedal calibration persist. Disconnect pauses both players.
- Logitech Formula Force EX hardware unavailable: simulated tests only; no wheel force feedback claim.
- Both humans may finish independently; retire is explicit. Finished cars cannot block active racers.
- Other vehicles and Duster: 165/198 km/h. Bigster: 180/225 km/h. Acceleration 18, handling 1 for everyone.
- Local SQLite lap/race rankings, names, mode/class filters; legacy 1.6 records stay separate.
- All six selected drivers visibly fit both Dacias. Preserve open-kart source models and Bigster 130% scale/pivots.
- Shared pause and target-player Change Car; modified/diagnostic races never save records.
- HDRI and broad collision overhaul deferred; necessary multiplayer collision corrections included.
- Commit and push each tested checkpoint. Development CI artifacts only: no release/tag/installer publication.

## Checkpoints

1. Branch/recovery notes/development CI: COMPLETE (this commit).
2. Independent input profiles, binding UI, persistence, wheel calibration: COMPLETE. 26 input checks, 96 catalog combinations and 11 driving checks pass. Race-loop ownership hookup follows in checkpoint 3.
3. Two-player race state, owned inputs, pause, finish, retirement: COMPLETE. 15 race checks pass; 26 input, 96 catalog, 11 driving and 37 garage acceptance checks pass. Recovery separates humans and barriers account for vehicle footprint.
4. Lobby, owned garage editing, shared-world split view, per-player HUD and results: COMPLETE. 21 presentation checks pass at 720p/1080p/ultrawide including Vulkan captures; 15 race, 37 garage and 24 legacy presentation checks pass.
5. Balanced performance and SQLite rankings: COMPLETE. 24 checks pass, including transactions, duplicate prevention, ordering/filtering, persistence, DNF/modified/diagnostic exclusion and corrupt-file preservation. Locked NuGet dependencies include Windows SQLite native support. Legacy best_time_astra remains untouched. Garage and AI use the same resolved rules as humans.
6. Cabin models and fits for six drivers in both Dacias: COMPLETE. 63 fit/identity/scale checks, 96 catalog combinations (2687 assertions), 229 Bigster wheel/geometry checks and 25 ranking checks pass. Vulkan front/side/pose captures cover all twelve combinations; contact sheets are committed. Static cartoon source components retain materials and proportions, with glove/arm positions adapted to the wheel; Mario uses a baked seated source rig and the existing human cabin pose is retained. CABIN appended as enum 3. Original kart assets and Bigster GLB unchanged.
7. Regression, collision, rendering/performance and offline development package: COMPLETE. Full shared-world three-lap race, contact/recovery/barrier checks and single-player regressions pass. Input coverage expanded to 35 checks, race to 21, rankings to 26. Actual 1080p RTX A1000: Vulkan 99.7 FPS / Compatibility 82.9 FPS means (45 seconds each). All twelve actual garage/driving combinations inspected. Separate locked editor/release dependencies and exported-assembly/native-SQLite guards added. Fresh extracted self-contained development ZIP passes offline smoke. See LOCAL2PLAYER_VALIDATION.md and qa-local2player JSON reports. Physical Logitech wheel remains unverified.

## Verification

Pinned Godot 4.7.2 .NET; Python NumPy/Pillow; Blender 4.5 for derived cabin meshes.
`tools/check_local2player.ps1` runs available feature tests plus preserved core regressions.
Real-renderer tests use `-- --drive-test` and isolated user data; never alter personal records.
At integration: 720p/1080p/ultrawide, Vulkan and Compatibility, six-racer split-screen 1080p target60 FPS.
Input tests cover device isolation, persistence, rebind, unplug and assignment conflicts.
Race tests cover independent humans, finish/retire, safe swap, impacts and ordered recovery.
Rankings test transactions, duplicates, DNF/modified/diagnostic exclusion, read failures and legacy migration.
Cabin captures must cover all twelve combinations and tire-center regression remains required.

## Resuming

Read this journal and `git log --oneline -10`; inspect `git status` before edits.
Only complete tested checkpoints are pushed; note any unfinished work below before ending a turn.
GitHub: amilapcsgit/Leo_Racer, branch local2player. Base main/bigster releases remain intact.
