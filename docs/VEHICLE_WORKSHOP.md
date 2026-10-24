# Offline Vehicle Workshop

In Content / Vehicles choose **Import GLB** to select a local model, or choose
**Vehicle Workshop** to open the companion first. `Vehicle Workshop.cmd` runs it
without opening the game menu. It reuses the installed engine and needs no Godot
editor, Python, Blender, internet connection or account.

1. Import a self-contained GLB. The original stays untouched. Inspect its measured
   dimensions, adjust rotation/scale, then **Reinspect / Suggest four wheels**.
   Game forward is **-Z**, up is **+Y**. Suggestions do not prove which end is front;
   inspect the front marker. The scale suggestion targets a 4.8 m car, not an
   authoritative real-world dimension. For the supplied raw BYD use scale 100 and
   Y rotation 180 degrees; its resulting length is about 5.11 m.
2. Confirm front-left, front-right, rear-left and rear-right. Search the component
   list by name, role or island ID. Assign rotating pieces and stationary calipers
   separately. Exclude a spare wheel. Use the highlighted guided region to find
   nearby islands; for joined geometry, edit its region and split selected
   triangles inside it, then assign the separated pieces.
3. Apply/Validate. Check spin, steering and optional collision overlay. Correct
   wheel pivots, rolling radii and axles as needed. Edit blue boost anchors at the
   rear (+Z). No visible driver is added. Camera controls set the thumbnail view.
4. **Private Test Drive** opens an isolated arcade proving ground. It reads P1's
   local controls (keyboard fallback), does not start a race and never creates a
   ranking session. Escape closes it. Return to the Workshop to finish setup.
5. Choose a unique ID, author/license and a writable destination. **Install Vehicle
   Folder** exports and validates the converted model, JSON, thumbnail, license
   and conversion report before publishing the complete folder. Existing folders
   are protected; use a new ID for edited copies. Closing the companion refreshes
   the game's list. A manual Refresh Content is also available outside races.

Share the complete folder under `GameAssets/vehicles/<id>/`. Vehicle API 1 is
unchanged. New content is modded/unranked; official local records are preserved.
Keep geometry and texture budgets appropriate for six racers. Import cost is
separate from driving performance; arbitrary downloaded models are not optimized
automatically. The Workshop never relies on editor-only texture compression.

Live skinned meshes require a static-pose export. Missing tire geometry must be
repaired in a modeling tool. Region splitting separates existing triangles and
does not reconstruct hidden/missing surfaces. Godot warns that the supplied BYD
uses differing UV sets for normal/albedo textures; normal-map appearance can
differ even though available geometry attributes and imported material data are
preserved. Retain the source model's redistribution terms.

## Independent tool updates

The initial core update supplies `--vehicle-workshop` and `--workshop-test` entry
points. After that, `Tools/VehicleWorkshop/workshop.pck` and `workshop.json` can be
replaced together without rebuilding the executable/core. Tool API 1 targets core
2.x (minimum 2.2) and Godot 4.7. Its namespaced converter avoids stale core script
remaps. Source models remain loose and authoritative; runtime caches are disposable.

From a developer checkout with the bundled Python on PATH:

```powershell
./tools/build_content.ps1 -Target workshop -Output build/VehicleWorkshop
```

This produces an independent tool ZIP and SHA256 without invoking executable
export. Build an assembled two-vehicle development package with the existing
`core` and `distribution` targets. Native dialogs and per-monitor Windows DPI
need physical desktop verification; automated tests use embedded dialogs for
deterministic event routing.
