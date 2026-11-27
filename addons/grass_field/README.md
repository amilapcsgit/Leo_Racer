# Grass Field

Author: L.J. Amila Prasad Perera

Grass Field is a Godot 4.7 Forward+ addon for world-anchored ground cover. It reuses spatial MultiMesh batches, varies geometry and density with distance, and renders short-lived wind and trample effects without per-blade nodes.

## Install

1. Copy `addons/grass_field` into your project and open it in the Godot 4.7 editor to register the script classes. The editor plugin can be enabled in Project Settings → Plugins. The runtime nodes work in exported builds.
2. Add a `GrassField`, assign the active camera in `cameras`, and assign its terrain provider. For split-screen, assign both cameras in slot order. Reserve render layers 11 and 12 for grass, or set `first_view_layer` and `second_view_layer` to two unused layers. Exclude these layers in any other cameras sharing the same world, such as rear-view mirrors.
3. Customize a `GrassProfile` for blade size, palette, wind, density, view range, and recovery. Match its palette to the existing grass terrain texture, which carries coverage beyond the grass draw distance.
4. Add a `GrassInteractor` to an actor or wheel contact. GrassField finds registered interactors automatically. Place contact markers at ground level and hide or remove them when inactive. Trail history is local to each view, and movement over 24 m between samples starts a new stroke.

Games can call `GrassField.set_detail(distance, density)` to cap draw distance and multiply the profile's density at runtime. The field reuses the pool allocated for the profile.

## Terrain3D

Install [Terrain3D 1.1.0](https://github.com/TokisanGames/Terrain3D/releases/tag/v1.1.0-stable) for the live provider. Add `GrassTerrain3DProvider`, assign the terrain, and list the paint texture IDs that should grow grass. Manually painted base and overlay weights, holes, missing regions, and slope affect eligibility. Automatic terrain shader cells are excluded by default. Enable `allow_auto_shader` to allow grass in those cells subject to slope and hole checks. Projects without Terrain3D can use the baked provider.

Choose `addons/grass_field/demo/demo.tscn` and run the scene. It generates a 1.37 km moving route across Terrain3D regions, a painted dirt path, a hole, a steep bank, and a missing region. Press **R** to return to the starting area. Pass `--stock-grass` after Godot's `--` separator to switch the demo to Terrain3D's included particle example. Pass `--grass-demo-output=<existing-directory>` to run the visual probe and save checkpoint PNGs.

## Baked tracks

Set a `GrassBakedProvider`'s `bake_path` to a `GrassBake` resource. Supply a non-mipmapped RG float ImageTexture. R contains world-space ground height and G marks eligibility (1 for grass and 0 for excluded cells). Set `origin` to the lower XZ corner, `spacing` to meters per texel, and `elevation` to the minimum and maximum eligible heights for culling. Texels are sampled at their centers. Bake masks with enough clearance for blade width near roads, pavement, water, and walls.

## Profiling

Compare grass off and on using identical camera paths and resolutions. Check frame-time percentiles and GPU time on the target renderer and device. Candidate instance counts include masked blades and batches the engine may cull. Watch footage across tile and region boundaries at the highest expected camera speed. Second cameras multiply rendering work, so profile split-screen separately.
