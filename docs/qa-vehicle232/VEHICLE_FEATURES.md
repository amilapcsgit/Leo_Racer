# Vehicle lights, actions and race camera — 2.3.2

Bigster now supplies automatic brake/reverse lamps, switchable headlights and a
sliding sunroof. Other cars can opt in without vehicle-specific scripts. Their
driving physics and collision boxes are independent of these visual features.

| Action | Keyboard | Gamepad |
|---|---|---|
| Headlights | L | D-pad left |
| Vehicle Action 1 | O | D-pad up |
| Vehicle Action 2 | K | D-pad down |
| Hold Look Back | C | Right-stick click |
| Orbit camera | Hold right mouse and drag | Right stick |

Bigster assigns Action 1 to its sunroof and leaves Action 2 unassigned. Controls
shows the selected car's action names. Existing assignments survive migration;
new defaults that conflict with them remain unbound. Shared-keyboard P2 uses
Numpad 1/2/3/0 for headlights, actions 1/2 and Look Back. Wheel buttons and camera
axes can be learned through the existing binding controls.

The camera enters reverse view below −0.75 m/s after 0.15 seconds. It returns
above +0.25 m/s, or when accelerating forward from rest. Active orbit overrides
held Look Back, which overrides automatic reverse view. Orbit recenters after
one second without input; holding right mouse keeps the orbit active. Mouse
ownership follows the keyboard player, or P1 when both players share a keyboard.
Every local player has independent camera state and terrain/wall avoidance.

## Authoring a vehicle

Use **Content → Vehicles → Set Up Vehicle**, then scroll to **Lights and Vehicle
Actions**. Select the lamp role, exact mesh and material, and bind its surface.
Projected lamps have an optional anchor in model space, rotation, range and
energy. Preview brake/reverse states and toggle headlights before the private
test drive. Add up to two named actions, select the moving node, and enter its
closed/open offsets and rotations. Imported AnimationPlayer clips can also be
selected. Saving retains the original model and writes portable metadata.

Coordinate convention: +Y is up, −Z forward, +Z rearward. Anchors and transform
offsets use the unnormalized model coordinate system; the vehicle normalization
is applied once to the complete rig. Rotation offsets are Euler degrees. A
transform action multiplies its closed/open offsets onto each node's bind pose.
Nodes containing a wheel or multiple parts can be bound as a group.

Reimporting an already authored portable car through the companion converter
copies its GLB byte-for-byte and retains the existing rig, materials and clips.
Use Set Up Vehicle for subsequent corrections. This avoids exporter changes to
node prefixes or material names invalidating exact bindings. New raw imports
still follow the existing four-wheel conversion workflow.

## Vehicle API 1 additions

The optional `lighting` and `actions` arrays default to empty. Existing packages
remain compatible. Feature packages should declare `core.min: "2.3.2"`.

```json
{
  "lighting": [
    {
      "role": "head",
      "targets": [{"node": "Body/Headlamp", "material": "HeadlampWhite"}],
      "anchor": [-0.7, 0.9, -2.1],
      "rotation": [-5, 0, 0],
      "range": 26,
      "energy": 2.2
    }
  ],
  "actions": [
    {
      "slot": 1,
      "name": "Sunroof",
      "type": "transform",
      "duration": 1.6,
      "targets": [{"node": "Body/RoofPanel", "open_position": [0, 0.065, 0.68]}]
    }
  ]
}
```

Lamp roles are `head`, `tail`, `brake`, and `reverse`. Brake groups normally
include dim running illumination; `running: false` makes a dedicated high-mounted
stop lamp stay dark until braking. An animation action instead supplies
`type: "animation"`, `player` (a relative AnimationPlayer path), and `clip`.
Duration controls travel time in either direction. Repeated presses reverse an
unfinished transition rather than restarting it.

The validator bounds array sizes, light count, coordinates, durations, range and
energy, rejects escaping node paths/nonfinite values, and enforces unique action
slots. Missing optional model targets produce diagnostics and disable the
affected group or action. Every vehicle gets separate animated materials and
action state. Projected lights have no shadows and fade with distance; emissive
surfaces remain visible in both renderers. No package-provided scripts execute.

## Reproduction

`tools/author_bigster_features.py` derives the updated GLB from the unchanged
checkpoint-024 portable model. Bigster package 1.2.1 corrects the earlier 1.2.0
optical mapping: reverse uses the separate right rear bumper lamp, while the
upper clusters have narrow red Y rails over passive red lenses. The rails are
clipped against each original surface triangle to preserve lens curvature;
mirrored meshes are matched spatially because their vertex orders differ.
Main headlamp reflector cells and the signature strips both illuminate. Black
housings, central rear indicators and the opposite lower red lens are passive.
The derivative adds 72 optical-rail triangles; wheels, normalization and handling
are unchanged. `feature-authoring.json` records hashes and corrections. The source
downloads and Blender checkpoint stay untouched.

Lamp locations were checked against the supplied photographs and the
[Dacia Bigster manual](https://www.user-manual.dacia.com/en/content/bigster/practical-advice/headlights-lights-replacing-bulbs/exterior-lighting-replacing).
Its reversing lamp 9 sits under the rear bumper, separately from the upper LED
stop/side lamps. The yellow manual overlay identifies a part; the reversing
lamp emits white. The red lower lamp seen in the night photograph is a separate
rear fog lamp and does not become a white upper-cluster light.

`tools/build_vehicle232.ps1` builds the Windows candidate from the v2.3.1 local
baseline. `tools/qa_vehicle232.py` runs isolated diagnostics and records complete
logs. Exported-game camera verification uses the compiled opt-in entry point
`-- --drive-test --vehicle-check=cameras`; it does not depend on editor-only
command-line script execution. Packaging creates a test-build ZIP, Bigster ZIP,
evidence ZIP and SHA256 checksums without publishing a GitHub release.
