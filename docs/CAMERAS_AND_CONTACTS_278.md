# Optional Vehicle API 1 metadata in 2.7.8

Existing definitions remain valid. No model or source-package change is required. Core-authored profiles override only verified official vehicle IDs; unreviewed add-ons retain generic contact feedback and do not acquire cockpit support automatically.

`camera_views` is an optional dictionary with `cockpit: true`, `eye: [x,y,z]` and `rotation_degrees: [pitch,yaw,roll]`. Coordinates are in the resolved vehicle frame (metres, forward -Z). The eye must be finite and within ten metres of the origin. Author and review cockpit anchors against the actual normalized runtime model; a detailed exterior does not qualify an interior. The engine owns view changes, per-player visibility, look-back and obstruction policy.

`contact_shapes` is an optional array of up to four box definitions. Each has `size_fraction: [x,y,z]` and `center_fraction: [x,y,z]`, relative to the existing collision size and center. Fractions are independent of runtime normalization. Boxes must be finite, positive and enclosed by the declared collision envelope. Invalid/absent metadata falls back to the existing single box. Recovery and spawn clearance retain the conservative full envelope.

Bigster and both Dusters use core-authored two-box lower-body/cabin profiles in `assets/config/collision-shapes-v278.json`. Their floor-contact bottom and existing outer envelope remain stable. Body-only damage permissions remain in the reviewed material allowlist; glass, lights, wheels, interiors and decals remain excluded.

Contact events contain `participants`, legacy-compatible `kart`/`other`, world `point`/`normal`, `normal_speed`, `tangent_speed`, `surface` and `phase` (`impact`/`scrape`). Only core physics emits authoritative events. Particles/audio/rumble and surface-conforming damage overlays consume them; Vehicle API packages remain data-only.

Global presentation limits: 256 skid meshes, 16 simultaneous contact emitters, eight recyclable damage patches per car. World-space contact effects and skid marks are shared between viewports; attached vehicle geometry uses dedicated per-player visibility layers. Camera choices never change physics, package signatures or record eligibility.
