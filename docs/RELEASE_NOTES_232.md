# Leo Racer 2.3.2 — Orbit Camera and Vehicle Features

[Download the Windows installer](https://github.com/amilapcsgit/Leo_Racer/releases/latest/download/LeoRacer-Setup.exe)

## Install everything or choose components

The installer is fully offline. **Complete** installs all three tracks and all
48 cars; **Standard** installs three tracks and the 16 default cars; **Custom**
lets you choose tracks and the 32 additional cars. At least one track is required.
Astra Lotus Coast, Colombo City Grand Prix and the improved Kandy Lake Circuit
are included. No separate Godot/.NET installation is needed.

Portable users: extract `LeoRacer-2.3.2-win64.zip` and run `LeoRacer.exe`. It contains
three tracks and 16 default cars. Additional cars are in the separate add-on ZIP.

## New camera and vehicle functions

- Automatic reverse camera, held Look Back, and mouse/right-stick orbit with
  smoothing, recentering and terrain/wall avoidance. Each split-screen player
  has independent camera state.
- Bigster 1.2.1 has corrected narrow red Y-shaped rear LED rails, a separate
  white reversing lamp in the rear bumper, and main headlamp optical cells plus
  signature strips. Brake, reverse and headlight states work independently.
- Headlight toggle and two remappable vehicle-action slots. Bigster Action 1
  opens/closes the existing sliding sunroof; Action 2 is unassigned.
- Workshop lamp-surface/anchor and action authoring, portable feature metadata,
  preview controls and compatibility with older car packages. Other cars can
  opt in; this release does not add new lamp geometry/actions to all 48 cars.
- Existing Kandy scenery improvements and startup/loading punctuation fixes
  are retained. Kandy's exact unchanged course/scenery are now registered as
  official content, allowing eligible unmodified races to set records.

| Control | Keyboard | Controller |
|---|---|---|
| Headlights | L | D-pad left |
| Vehicle Action 1 / Bigster sunroof | O | D-pad up |
| Vehicle Action 2 | K | D-pad down |
| Look Back, held | C | Right-stick click |
| Orbit | Right-mouse drag | Right stick |

Change bindings in Controls. Existing assignments take precedence over new
conflicting defaults. Shared-keyboard P2 uses Numpad 1/2/3/0 for these buttons.

## Upgrade and preservation

Existing settings, control profiles, records and user-added cars keep their
locations. Modified files replaced by the installer are backed up under
`ContentBackups`. Deselecting already-installed tracks/cars preserves them.
Uninstall removes owned unchanged files and preserves user content/modifications.
Imported additional cars remain unranked and have no visible driver.

## Verification and limits

The candidate was user-tested. Automated evidence includes 53 focused feature
checks, 69 packaged camera checks per renderer, six three-lap single/split-screen
runs across all tracks, 48-car validation, and extracted SDK-free startup checks.
Release checks exercise Complete/Standard/Custom, the one-track requirement,
upgrade from 2.3.1, modified-file backups and preservation through uninstall.
The evidence ZIP contains reports and close-up lamp captures in both renderers.

Forward+ is recommended. Compatibility mode works with simpler effects and
occasional frame spikes; renderer resource-cleanup warnings remain documented.
Physical controller/wheel hardware coverage remains unverified; automated input
checks use injected device events. Force feedback is not included.

Bigster's standalone package requires core 2.3.2. Track routes, handling,
checkpoints and course revisions are unchanged. Original sources and downloads
were left untouched. Attribution and SHA256 checksums are attached.

Source branch: `orbitcamera`. Prior releases remain available for rollback.
