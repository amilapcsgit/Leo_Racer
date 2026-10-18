# Colombo art and asset pipeline

## Preserved foundation

All **34 existing model GLBs** match the working v1.1 sources byte for byte; see `qa-colombo/geometry-baseline.json`. The published main branch contained a truncated `lotus_coast.glb` (6,690,696 bytes with an 8,576,904-byte header). Colombo restores the exact working 8,576,904-byte file and its editable Blender source. No track or vehicle remodelling was performed.

## New assets

- `blender/build_colombo.py`: three feathered coconut palms with lower-detail variants, a tuk-tuk, and an electric city car. Palms are also saved as individual editable `.blend` files; both vehicles are in `colombo_props.blend`.
- Quaternius Stylized Nature MegaKit **Standard**, CC0: eight bushes, plants, fern, grass, and rock models. Only the free Standard assets supplied for this project were used. Inputs and hashes are recorded in `asset-lock.json`; converted GLBs are included.
- EZ Tree, MIT: three deterministically seeded shade-tree resources, baked offline. Runtime uses shared meshes rather than running a procedural tree generator for every instance.
- Terrain3D, MIT: two saved coastal regions, with no racing collision. New foliage/props use spatially rebased MultiMesh batches and distance-based palm LODs.
- Original vector neon lion and Sri Lankan-inspired event banner artwork. The banner is an original event design, not an official Port City logo.

## AmbientCG PBR maps

All three 2K JPG source sets are CC0:

| Material | Use |
| --- | --- |
| [Asphalt023S](https://ambientcg.com/view?id=Asphalt023S) | Road color, OpenGL normal, roughness; procedural wetness variation |
| [Concrete034](https://ambientcg.com/view?id=Concrete034) | Building detail and derived square shore textures |
| [PavingStones001](https://ambientcg.com/view?id=PavingStones001) | Promenade paving color, OpenGL normal, roughness |

Maps use mipmaps and filtered world-space sampling. Color maps use sRGB shader hints; normal/roughness maps are linear. The shore derivatives are repacked square inputs for Terrain3D. Metal/paint, rubber, glass, and foliage retain separate material responses.

## Presentation

`LeoArtProfile` centralizes tuning. The final sun uses a softer warm tint than the initial sample to preserve blue paint and green foliage. Warm bay haze remains localized; the foreground stays readable. Static reflection probes, bounded SSR, SSAO, ACES, and controlled glow support wet asphalt and cobalt/gold finishes.

Rokojori sequences drive nitro ignition, sustain, and cooldown. Presentation events never alter vehicle forces or race progress. The final camera composer combines the interpolated follow pose with bounded FOV, roll, and impact offsets. GPU particles and fixed-size road-trace pools are recycled; recovery clears their history. Compatibility mode omits heat refraction, volumetric fog, SSR, probes, and GPU ribbon trails in favor of simpler particles.
