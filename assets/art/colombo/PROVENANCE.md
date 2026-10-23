# Colombo midday environment

`midday_panorama.png`: generated with the built-in imagegen tool, 23 October
2026. Native output 1774 × 887, 2:1 equirectangular. It is a visual matte, not
captured geography or measured HDR radiance. A narrow wrap blend and horizon
offset are applied by the sky shader. No third-party photo pixels are embedded.

Prompt:

> Create a production game environment texture: a seamless 360 degree full-sphere 2:1 equirectangular panorama, wide exact 2:1 aspect ratio, ideally 4096x2048. Colombo Sri Lanka seafront viewed from offshore near Galle Face / Port City in clear bright tropical midday. This is a distant sky and skyline matte, NOT a postcard composition. Horizon must be perfectly level and at exactly 50% image height; buildings confined to a thin small band just above horizon, maximum 8% image height. Upper half mostly luminous tropical blue sky with restrained high scattered white clouds and light coastal haze. Right half of horizontal panorama has realistic distant Colombo coastal city massing inspired by One Galle Face twin towers, the slim modern hotel/apartment towers and low Fort district roofs; recognizable relationships but no close buildings. Left half has mostly open Indian Ocean horizon with only very faint harbour cranes near the right transition. Bottom half uninterrupted calm muted turquoise-blue ocean, smoothly simpler towards nadir. No Lotus Tower (we have a 3D landmark), no duplicated big landmark. Entire image is genuinely an equirectangular environment map with polar compression and matching left and right edges, no camera lens frame, no cropped 180 degree scene. Neutral clear midday sunlight, no baked visible sun disk, no sunset, no orange grading, no people, no cars, no text, no logos, no foreground objects, no promenade. Grounded realistic photographic atmosphere, soft distant haze, city NOT surrounding the full 360 horizon. Save the image and return its local file path.

`midday_lighting.exr`: independently authored linear floating-point radiance,
reproducible with `tools/bake_colombo_lighting.gd`. A procedural atmosphere and
explicit small solar disk produce a peak of approximately 1801, rather than
expanding PNG code values into floats. Direction matches the track's directional
sun. Shader cubemap passes use this map; visible background uses the generated
matte. The sky is static so cubemap convolution is not repeated every frame.

Nearby and middle-distance city geometry provides parallax. The distant matte is
Colombo-inspired art; its buildings cannot provide positional parallax over 5.5 km.
