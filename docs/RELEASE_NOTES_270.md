# Leo Racer 2.7 Ultra

21 cars, six drivers, three Sri Lankan circuits—and a more coherent racing UI.

- The garage now shows transparent renders of the actual selected car, aligned with its initial 3D camera. A short dissolve hands over to the live model, which rotates automatically after two seconds. Selected and neighboring cars prepare through a bounded cache. Future imports have a transparent fallback and receive their own cached captures.
- Let's Race uses car-focused player cards, clear cyan/gold player identities, a track outline, lighting selection, and a 1–10 lap selector. The default remains three laps. Race completion, HUD, loading, final-lap announcements, lighting progression and records use the selected length.
- Identical controller names are distinguished with session pad numbers and player ownership. Assign a pad by pressing A; Identify highlights its player card and briefly vibrates that controller. Ambiguous reconnects still require confirmation. Controller rumble has separate crash, scrape, bump and landing effects, with enable, strength and test controls.
- The existing arcade controller now uses lighter gravity, restrained floor snap, supported road-normal alignment, controlled airborne grip, damped suspension and bounded collision restitution. Existing speed, steering, boost balance, authored collision envelopes and recovery remain in place.
- Track selection draws real course outlines, including Kandy, and scrolls to accommodate additional installed tracks. Records have a champion banner, trophy artwork, vehicle thumbnails, visible lap/metric filters and historical balance filters. Settings group audio, display/camera and controls/accessibility into compact columns.
- Earlier records remain available under historical filters. Lap metadata is additive and keeps the database readable by 2.6. New driving rules use a separate 2.7 record identity. Custom cars and modified races retain their existing ranking restrictions.
- Windows validation now stages checksum-pinned content before tests, uses the current roster and packaging, and preserves failure logs. Preview preparation drains before race transitions and shutdown. Actual contact preparation is warmed behind the loading screen without leaving cosmetic damage.

The Windows portable folder and installer work offline without a development SDK. Keep the complete portable folder together; use **Play Compatibility.cmd** if Vulkan is unavailable. The Vehicle Workshop remains included.

Extract portable releases into a new folder. The installer preserves unrelated custom content and backs up modified managed files under `ContentBackups`. Settings, controller preferences and records retain their existing user-data location. Source assets, vehicle attribution and licenses remain preserved.

See **TEST_REPORT.md** for the exact checks, performance measurements and remaining limitations. Gamepad rumble is supported; steering-wheel force feedback is unavailable. Generated trophy/fallback artwork and its prompts are documented in the source artwork provenance file; official car cutouts are native model renders.

Measured limits: all 13 sampled 2.7 Forward+ cases met the 16.7 ms p95 goal. Kandy split-screen Compatibility samples exceed it (16.744–17.790 ms p95), and brief cold garage/streaming stalls remain. Physical two-Xbox reconnect and rumble feel are unverified because no controllers were available.

[Validation and full timing table](https://github.com/amilapcsgit/Leo_Racer/releases/download/v2.7.0/TEST_REPORT.md) · [SHA256 checksums](https://github.com/amilapcsgit/Leo_Racer/releases/download/v2.7.0/SHA256SUMS.txt)
