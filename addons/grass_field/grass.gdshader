shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform int terrain_mode;
uniform sampler2D baked_samples : filter_nearest, repeat_disable;
uniform vec2 baked_origin;
uniform float spacing = 1.0;
uniform highp sampler2DArray height_maps : filter_nearest, repeat_disable;
uniform highp sampler2DArray control_maps : filter_nearest, repeat_disable;
uniform int region_map[1024];
uniform int region_size = 256;
uniform uint eligible_textures = 1u;
uniform bool allow_auto = false;
uniform float minimum_up = 0.83;

uniform sampler2D trail_map : filter_nearest, repeat_disable;
uniform vec2 trail_origin;
uniform float trail_size = 64.0;
uniform vec2 viewer;
uniform int seed = 41;
uniform bool far_lod = false;
uniform float near_lod = 22.0;
uniform float far_lod_start = 39.0;
uniform float fade_end = 90.0;
uniform float density = 0.8;
uniform float blade_height = 0.36;
uniform float wind_strength = 0.12;
uniform vec4 root_color : source_color;
uniform vec4 tip_color : source_color;

varying float blade_tone;

float random_cell(ivec2 cell, uint salt) {
	uint value = uint(cell.x) * 0x9e3779b9u ^ uint(cell.y) * 0x85ebca6bu ^ uint(seed) ^ salt;
	value ^= value >> 16u;
	value *= 0x7feb352du;
	value ^= value >> 15u;
	value *= 0x846ca68bu;
	return float((value ^ (value >> 16u)) & 0xffffffu) / 16777216.0;
}

ivec3 terrain_index(ivec2 sample_point) {
	ivec2 region = ivec2(floor(vec2(sample_point) / float(region_size)));
	ivec2 key = region + ivec2(16);
	if (any(lessThan(key, ivec2(0))) || any(greaterThanEqual(key, ivec2(32)))) {
		return ivec3(0, 0, -1);
	}
	return ivec3(sample_point - region * region_size, region_map[key.y * 32 + key.x] - 1);
}

vec2 terrain_height(ivec2 point) {
	ivec3 index = terrain_index(point);
	if (index.z < 0) {
		return vec2(0.0);
	}
	return vec2(texelFetch(height_maps, index, 0).r, 1.0);
}

vec2 baked_height(ivec2 point) {
	ivec2 dimensions = textureSize(baked_samples, 0);
	if (any(lessThan(point, ivec2(0))) || any(greaterThanEqual(point, dimensions))) {
		return vec2(0.0);
	}
	return texelFetch(baked_samples, point, 0).rg;
}

float height_or(vec2 sample_value, float fallback) {
	return mix(fallback, sample_value.x, step(0.5, sample_value.y));
}

vec2 ground(vec2 root) {
	vec2 point = terrain_mode == 0 ? (root - baked_origin) / spacing - vec2(0.5) : root / spacing;
	ivec2 nearest = ivec2(floor(point + 0.5));
	vec2 center;
	if (terrain_mode == 0) {
		center = baked_height(nearest);
		if (center.y < 0.5) {
			return center;
		}
	} else {
		ivec3 index = terrain_index(nearest);
		if (index.z < 0) {
			return vec2(0.0);
		}
		uint control = floatBitsToUint(texelFetch(control_maps, index, 0).r);
		if ((control & 4u) != 0u) {
			return vec2(0.0);
		}
		uint base_id = (control >> 27u) & 31u;
		uint overlay = (control >> 22u) & 31u;
		float blend = float((control >> 14u) & 255u) / 255.0;
		float painted = mix(float((eligible_textures >> base_id) & 1u), float((eligible_textures >> overlay) & 1u), blend);
		bool automatic = (control & 1u) != 0u;
		if ((automatic && !allow_auto) || (!automatic && painted < 0.5)) {
			return vec2(0.0);
		}
		center = vec2(texelFetch(height_maps, index, 0).r, 1.0);
	}
	ivec2 lower = ivec2(floor(point));
	vec2 a = terrain_mode == 0 ? baked_height(lower) : terrain_height(lower);
	vec2 b = terrain_mode == 0 ? baked_height(lower + ivec2(1, 0)) : terrain_height(lower + ivec2(1, 0));
	vec2 c = terrain_mode == 0 ? baked_height(lower + ivec2(0, 1)) : terrain_height(lower + ivec2(0, 1));
	vec2 d = terrain_mode == 0 ? baked_height(lower + ivec2(1)) : terrain_height(lower + ivec2(1));
	vec2 part = fract(point);
	float h00 = height_or(a, center.x);
	float h10 = height_or(b, center.x);
	float h01 = height_or(c, center.x);
	float h11 = height_or(d, center.x);
	vec2 gradient = vec2(mix(h10 - h00, h11 - h01, part.y), mix(h01 - h00, h11 - h10, part.x)) / spacing;
	if (terrain_mode == 1 && inversesqrt(1.0 + dot(gradient, gradient)) < minimum_up) {
		return vec2(0.0);
	}
	return vec2(mix(mix(h00, h10, part.x), mix(h01, h11, part.x), part.y), 1.0);
}

void vertex() {
	vec3 model_root = MODEL_MATRIX[3].xyz;
	ivec2 cell = ivec2(floor(model_root.xz * 0.75));
	vec2 jitter = (vec2(random_cell(cell, 1u), random_cell(cell, 2u)) - 0.5) * 1.1;
	vec2 root = model_root.xz + jitter;
	float distance_to_view = distance(root, viewer);
	float crossfade = smoothstep(near_lod, far_lod_start, distance_to_view);
	float lod_choice = random_cell(cell, 3u);
	float fade = 1.0 - smoothstep(fade_end * 0.72, fade_end, distance_to_view);
	float threshold = random_cell(cell, 4u);
	float coverage = density * mix(0.46, 1.0, 1.0 - crossfade) * fade;
	bool selected = (far_lod ? lod_choice < crossfade : lod_choice >= crossfade) && threshold < coverage;
	vec2 surface = vec2(0.0);
	if (selected) {
		surface = ground(root);
	}
	if (surface.y < 0.5) {
		VERTEX = vec3(0.0);
	} else {
		float angle = random_cell(cell, 5u) * TAU;
		mat2 rotation = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
		float bend = UV.y * UV.y;
		float size = mix(0.65, 1.4, random_cell(cell, 6u)) * smoothstep(0.0, 0.12, coverage - threshold);
		VERTEX.xz = rotation * VERTEX.xz * size;
		VERTEX.y *= size * blade_height;
		vec2 trail_uv = (root - trail_origin) / trail_size;
		vec3 trail = vec3(0.0);
		if (all(greaterThanEqual(trail_uv, vec2(0.0))) && all(lessThan(trail_uv, vec2(1.0)))) {
			trail = textureLod(trail_map, trail_uv, 0.0).rgb;
		}
		float gust = sin(dot(root, vec2(0.23, 0.14)) + TIME * 1.7) + 0.35 * sin(root.y * 0.52 - TIME * 2.1);
		VERTEX.xz += jitter + vec2(1.0, 0.43) * gust * bend * wind_strength * (1.0 - trail.b)
			+ (trail.rg * 2.0 - 1.0) * trail.b * bend * 0.65;
		VERTEX.y = VERTEX.y * (1.0 - trail.b * 0.82) + surface.x - model_root.y - 0.025;
		NORMAL.xz = rotation * NORMAL.xz;
	}
	blade_tone = random_cell(cell, 7u);
}

void fragment() {
	ALBEDO = mix(root_color.rgb, tip_color.rgb, clamp(UV.y, 0.0, 1.0)) * mix(0.83, 1.16, blade_tone);
	ROUGHNESS = 0.87;
	SPECULAR = 0.19;
}
