# Leo Racer 2.6.0 preview

The default Duster is now Duster_My_2014 in Bianco Ghiaccio, with factory longitudinal rails. Saved `duster` selections continue to work. Dacia Duster 2024 in Terracotta is car 21. Bigster remains the new-player and missing-content fallback.

Both Dusters include working lighting, four-door and trunk actions, separate recolorable paint, seven documented paint presets, and source attribution. Garage color selection is reserved for a future update.

The garage opens with metadata and a thumbnail, then streams the selected vehicle and driver before adjacent previews. The bounded cache retains at most three vehicle resources and estimates a 512 MiB budget. Navigation and Back remain available during loading.

Cosmetic suspension, explicit drift-tier camera pulses, drafting wind, peripheral speed feedback and pooled skid decals extend the existing driving presentation. The 2.5 movement, contact solver, cosmetic damage and measured-speed camera response remain intact. Reduced Motion suppresses the added movement and overlays. Compatibility and lower quality use the mesh skid backend. Compatibility Medium uses a single shadow cascade within 80 m (65 m in split-screen); High retains four. Kandy bake-only suns and environments are suppressed at runtime; the original static lightmap resources are retained. Opaque vehicle parts are batched within their interaction groups to reduce draw calls.

Static track lighting remains the default. Choose Dusk to Night in race setup to transition the shared environment using validated leader progress. Dynamic Medium lighting uses 64-pixel sky radiance, a 2 Hz sky/sun update and a nearer shadow budget; ambient light and fog blend at 10 Hz. Kandy uses a separate neutral indirect-light bake; original static lightmaps remain available. Static and dynamic records use separate V5 identities; earlier records remain in the database and can be viewed through legacy filters.

Official vehicles ship as namespaced Vehicle API 2 PCKs with compiled meshes, LODs, compressed mipmapped textures and presentation bounds. Vehicle API 1 loose mods remain supported. The Contributor SDK includes an independent PowerShell compiler. Ranking queries and writes use a serialized C# worker with immutable snapshots, cancellation and shutdown flushing.

This is a local preview, not a public GitHub release. See the accompanying validation report for measured performance, test coverage and known limitations. Cosmetic opening panels retain the fixed driving collision envelope. Paint colors are visual approximations, not measured factory values.
