# Leo Racer — AAA Visual Quality, Modular Architecture & UGC Modding Framework

This blueprint establishes the architectural evolution for **Leo Racer**, elevating its visual presentation to AAA racing game standards (e.g., *Forza Horizon*, *Need for Speed*, *Grid*), establishing a decoupled modular architecture, and providing a free User-Generated Content (UGC) ecosystem for custom vehicles and tracks.

---

## 1. AAA Visual Rendering Pipeline & Architectural Upgrade

### 1.1 Physical Lighting & High-Dynamic-Range Environment
To achieve photo-realistic rendering in Godot 4.7 Forward+ renderer:
- **Physical Light Units (Lux / Nits):**
  - Switch `WorldEnvironment` and Light nodes to physical units (`use_physical_light_units = true`).
  - Set direct sunlight intensity to ~100,000 lux for daylight and HDRI sky maps with physical exposure calibration.
  - Implement dynamic Auto-Exposure (Eye Adaptation) with min/max EV limits (`EV100: -2` to `16`), bloom thresholding, and histogram-based tone mapping (AgX or ACES Filmic tone mapping).
- **Global Illumination (SDFGI / Volumetric Fog):**
  - Enable **SDFGI (Signed Distance Field Global Illumination)** with 8 cascades and dynamic ambient occlusion for real-time indirect bounce light, particularly under bridges, urban alleyways, and tunnel entrances.
  - Integrate **Volumetric Fog** with custom scattering parameters, density noise textures, and light shafts (god rays) from sunlight breaking through palm trees and skyscrapers.
- **Screen-Space Refractions & Reflections (SSRR & SSIL):**
  - Enable **SSIL (Screen-Space Indirect Lighting)** for close-up ambient color bleeding between neon signs, hot tarmac, and car bodies.
  - Implement full **SSR (Screen-Space Reflections)** with roughness fade and planar reflection probes for wet pavement and vehicle windshields/side mirrors.

### 1.2 AAA Car Paint & Material Shading Architecture
- **Multi-Layer Clear Coat Car Paint Shader (`car_paint_pbr.gdshader`):**
  - **Base Coat:** Metallic flake / micro-glitter noise texture with view-dependent color shifting (chameleon/pearlescent effect).
  - **Clear Coat & Smoothness:** Dual-roughness specular response with coat weight control, coat tint, and normal map micro-scratches.
  - **Dynamic Dirt / Dust Mask:** Vertex color or procedural RGBA mask driving road dust accumulation on lower trim and mud splatter behind wheel wells.
  - **PBR Glass & Headlight Optics:** Refraction index ($n = 1.52$), Fresnel rim lighting, chromatic aberration on lens edges, and emissive LED projector daytime running lights (DRL).
- **Tire & Carbon Fiber Shaders:**
  - Anisotropic specular shading for brushed aluminum rims, carbon fiber weaves, and rubber tires with sidewall branding detail maps.
  - Heat glow shaders for brake discs under heavy deceleration.

### 1.3 Post-Processing & Cinematic Camera FX
- **Vehicle-Centric Motion Blur:**
  - Per-object velocity buffer motion blur combined with radial screen-space camera speed lines during Nitro/Super Drift.
- **Physical Depth of Field (DoF):**
  - Autofocus DOF targeting the player vehicle during gameplay, with wide aperture blur ($f/1.8 - f/2.8$) during vehicle selection, carousel inspect, and victory cinematic cameras.
- **Dynamic Weather & Road Wetness State Machine:**
  - Dynamic wetness layer adjusting tarmac roughness, specular intensity, puddles with rain drop ripple shaders (`rain_ripples.gdshader`), and tire spray particle emitter scaling based on moisture percentage.

---

## 2. Modular UGC & Modding Architecture (Free Expandability)

### 2.1 Vehicle UGC Framework (`.pck` / GLTF Vehicle Packages)
Users can design, export, and load custom vehicles into Leo Racer without recompiling the game.

```
user_mods/vehicles/custom_supercar/
├── manifest.json              # Identity, handling stats, sound profiles, cameras
├── vehicle.gltf / vehicle.pck # Mesh hierarchy, wheel nodes, driver seat transforms
├── engine_loop.wav            # Custom RPM sound curves
└── thumbnail.png              # UI preview icon
```

#### Node Hierarchy Standard for Custom Vehicles:
```
VehicleRoot (Node3D)
├── Chassis (MeshInstance3D) [Car Body + Interior]
├── Glass (MeshInstance3D)   [Transparent Shader]
├── Wheels/
│   ├── Wheel_FL (Node3D)    [Front Left Wheel & Brake]
│   ├── Wheel_FR (Node3D)    [Front Right Wheel & Brake]
│   ├── Wheel_RL (Node3D)    [Rear Left Wheel]
│   └── Wheel_RR (Node3D)    [Rear Right Wheel]
├── Anchors/
│   ├── DriverSeat (Marker3D)[Transforms for seated driver character]
│   ├── SteeringWheel (Marker3D) [Pivot for steering wheel rotation]
│   ├── Exhaust_L (Marker3D) [Nitro particle emitter spawn point]
│   └── Exhaust_R (Marker3D)
└── Cameras/
    ├── ChaseFar (Marker3D)
    ├── Cockpit (Marker3D)
    └── Bumper (Marker3D)
```

#### JSON Vehicle Manifest Specification (`manifest.json`):
```json
{
  "format": 1,
  "id": "community_f1_hypercar",
  "name": "Apex Formula 2026",
  "class": "supercar",
  "author": "TrackMaster99",
  "version": "1.0.0",
  "specs": {
    "top_speed_kmh": 210,
    "acceleration_m_s2": 22.0,
    "handling_factor": 1.15,
    "mass_kg": 950,
    "boost_capacity": 100
  },
  "driver_policy": "custom_or_catalog",
  "sound_profile": "v10_engine"
}
```

---

### 2.2 Track UGC Framework & Spline Track Builder

#### Track Data Directory Format:
```
user_mods/tracks/colombo_night_circuit/
├── manifest.json          # Track metadata, lap record category, environment profile
├── route.json             # Spline control points, track width array, banking angles
├── scenery.pck / GLTF     # Custom props, buildings, scenery models
└── mini_map.png           # HUD minimap texture
```

#### Spline Track Editor & Generator Tooling:
- **Spline Mesh Extruder (`TrackExtruder3D`):** Converts 3D Bezier curve checkpoints into smooth asphalt roadway meshes with UV tiling, curbs, rumble strips, and invisible collision walls.
- **Waypoint & AI Racing Line Generator:** Auto-calculates AI speed limits, braking zones, drift initiation points, and checkpoint trigger volumes from the route spline.
- **Scenery Placement & Grid Snap System:** In-game or Godot editor addon enabling modders to place barrier walls, grandstands, light posts, and boost pads along the track curve.

---

## 3. Repository Architecture & Codebase Modernization Strategy

### 3.1 Architecture Decoupling
- **Dependency Injection & Event Bus (`SignalBus.gd`):** Decouple `kart.gd` and `main.gd` by emitting standardized signals (`vehicle_boost_started`, `checkpoint_passed`, `lap_completed`) rather than direct node cross-references.
- **Resource-Based Catalog Pipeline:** Unify C# ranking bridges and GDScript catalog managers under an interface driven strictly by `Resource` definitions and runtime JSON validation.

### 3.2 Mod Loader Runtime Service (`ModLoader.gd`)
- Auto-discovers subdirectories in `%APPDATA%/LeoRacer/mods/` or `user://mods/`.
- Validates cryptographic SHA-256 hashes for official leaderboard entry while allowing unranked user play for custom/edited content.
- Dynamically registers custom vehicles into `GarageCatalog` and custom tracks into `LeoTrackDefinition`.

---

## 4. Implementation Roadmap

1. **Phase 1: Visual Pipeline Modernization**
   - Implement `car_paint_pbr.gdshader` and `rain_ripples.gdshader`.
   - Update default `WorldEnvironment` settings for SDFGI, SSIL, SSR, and volumetric fog.
2. **Phase 2: UGC Mod Loader Engine Integration**
   - Implement `scripts/content/mod_loader.gd` to load user `.pck` and `.gltf` vehicles at runtime.
   - Standardize vehicle node anchor verification script (`tools/verify_mod_vehicle.gd`).
3. **Phase 3: Community Track Builder Toolset**
   - Create curve-based road mesh generation addon in Godot.
   - Publish sample vehicle and track mod templates on GitHub with Blender export profiles.
