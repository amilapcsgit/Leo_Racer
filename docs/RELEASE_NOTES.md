# Leo Racer 1.7.0 — Local Two Player

Race together on one PC: **P1 left, P2 right**, two human racers plus four AI,
three laps around Colombo Coast. Each player chooses their own name, car,
driver and controls. Either player can pause; the second player keeps racing
after the first finishes.

- **CONTROLS:** saved keyboard/controller remapping and raw joystick/wheel
  calibration. Use one keyboard plus a controller/wheel, or two separate devices.
  Only one keyboard player is allowed. Disconnect pauses the race; indistinguishable
  controllers require owner confirmation.
- **RANKINGS:** named offline race-time and lap-time records, filtered by mode,
  speed class and vehicle. Legacy 1.6 bests remain separate. DNF, modified races
  and diagnostics never set new records. SQLite and its Windows runtime are included.
- **Balanced racing:** standard vehicles and Duster use 165/198 km/h; Bigster
  keeps 180/225 km/h, electric boost and braking regeneration. Everyone uses
  18 m/s² acceleration and handling 1.0.
- **All six drivers in both Dacias:** Sonic, Leo, Ellie, Rio, Shaven Leo and Mario
  now appear seated inside Duster and Bigster. Bigster retains its approved
  130% game size and corrected wheel rotation centers.
- Safer grid spacing, footprint-aware barriers and recovery, non-blocking
  finished cars, and player-targeted Pause → Change Car. Changed races are
  excluded from rankings.

Download **LeoRacer-Setup-1.7.0.exe** to install/update, or
**LeoRacer-Windows-1.7.0-Local2Player.zip** for portable play. Extract the whole
folder and run **Leo Racer Launcher.exe**. No editor, .NET SDK or database server
is required. **SHA256SUMS.txt** verifies every package; the binaries are unsigned.

Windows x64. Vulkan recommended; OpenGL Compatibility mode is available.
RTX A1000 1080p split-screen measurements averaged 99.7 FPS Vulkan and 82.9 FPS
Compatibility (45-second samples; not a guaranteed minimum).

Logitech Formula Force EX **physical compatibility remains unverified** because
hardware was unavailable. Input tests used simulated Godot device events; wheel
force feedback is not included. Colombo HDRI and the broader collision overhaul
remain future work.

Source and verification: `v1.7.0`, `docs/LOCAL2PLAYER_VALIDATION.md` and
`docs/qa-local2player/`. Version 1.6 remains available in previous GitHub releases.
