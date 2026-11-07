# Leo Racer 2.7.9 — closer to the drive

Driver-seat cockpits, clearer race preparation, more Sri Lankan loading artwork and a custom soundtrack refresh the existing offline arcade racer. The complete game retains **21 cars, six drivers, three tracks, solo racing and local split-screen**.

## Cockpits and instruments

- Reviewed driver-seat views for **Dacia Bigster, Duster My 2014 and Duster 2024**. Each steering wheel turns as one assembly, with model-specific dashboard clearance.
- Live cabin instruments and navigation/media displays. The 2014 keeps its analog cluster and adds a fitted navigation screen.
- The existing **analog RPM dial and digital km/h HUD** retain their design and position across Chase, Ghost and Cockpit, for each player.
- A shallow solo cockpit header presents position, lap, time and the current track/sector while leaving more of the forward view open.
- Visible cockpit mirrors use a **30 Hz refresh target**. Mirror work remains limited to the surfaces relevant to the current view.

See the [three-cockpit comparison](../README.md#a-closer-seat-to-the-action) and [cockpit implementation notes](COCKPITS_279.md).

## Race preparation and Game Logic

- Graphical keyboard, controller and wheel illustrations show each player's saved bindings during race loading. Solo and mixed-device split-screen have separate player guides.
- Calmer menu focus effects and clearer results cards, with best-lap information and personal-best comparisons where an applicable record exists.
- Settings now has **Graphics, Audio, Controls, Accessibility and Game Logic** tabs.
- **Allow Bigster as an AI opponent** is **off by default**. Changing it applies to the next new race or restart. Human players can continue choosing Bigster in either setting.

## Sri Lankan presentation

- A shared **23-image loading gallery**, including five new location heroes: **Galle Fort, Hikkaduwa, Nine Arch Bridge, Sigiriya and Sri Dalada Maligawa**.
- Artwork is shuffled between loading operations and stays steady during each one. Original images remain preserved; garage and billboard source art are excluded from the loading-hero set.
- More consistent dry asphalt, restrained road reflections, terrain detail and additional roadside planting across the existing tracks.

Loading screenshots combine illustrated background art with the runtime interface. Cockpit and exterior screenshots show actual in-engine views; captions identify the capture type.

## Music from boot to the finish

- Two user-supplied intro tracks accompany boot, loading, menus and the garage through one persistent music session.
- Kandy starts races with its own soundtrack; Astra Lotus Coast and Colombo City start with the coastal theme.
- The subsequent race pool contains **six tracks**: four user-supplied custom recordings, the original **Ceylon Afterglow**, and **Island Music**. Music transitions use short crossfades.
- All music is bundled for offline use. The five new conversions use 48 kHz stereo Ogg Vorbis, normalized around −18 LUFS and checked after decoding for peaks at or below −2 dBTP.
- Original MP3/WAV sources remain untouched. The custom recordings carry user-supplied provenance; conversion does not assign them a CC0 license. See [soundtrack credits and preparation](../licenses/customaudio279.md).

## Compatibility and release information

Existing handling, custom-car imports, saved settings and historical records are preserved. Race records continue separating lap counts and driving rulesets. Forward+ and Compatibility remain available; performance depends on the track, renderer, quality and player count.

Use the [latest official release page](https://github.com/amilapcsgit/Leo_Racer/releases/latest) for the installer, portable archive and SHA256 checksums. Current measured results, remaining checks and hardware limits are maintained in [VALIDATION_279.md](VALIDATION_279.md).

**Author: L.J. Amila Prasad Perera.** Created for Shaven Leo. The [custom non-commercial license](../LICENSE), earlier applicable permissions and third-party notices remain in force.
