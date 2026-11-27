class_name GrassField
extends Node3D

const SHADER := preload("grass.gdshader")
const Trail := preload("grass_trail.gd")
const Profile := preload("grass_profile.gd")
const Provider := preload("grass_provider.gd")
const Interactor := preload("grass_interactor.gd")
const TILE := 16.0
const ROWS := 12
const NEAR_LOD := 22.0
const FAR_LOD := 39.0
const MAX_INTERACTORS := 64

@export var provider: Provider
@export var profile: Profile = Profile.new()
@export var cameras: Array[Camera3D]
@export_flags_3d_render var first_view_layer: int = 1 << 10
@export_flags_3d_render var second_view_layer: int = 1 << 11

var views: Array[Dictionary] = []
var previous: Dictionary[int, Vector2] = {}
var clock := 0.0
var last_stamp := -1.0
var terrain_dirty := true
var near_mesh: MultiMesh
var far_mesh: MultiMesh
var ready_to_draw := false
var distance_cap := 110.0
var density_multiplier := 1.0

func _ready() -> void:
	if not provider:
		set_process(false)
		return
	if not profile:
		profile = Profile.new()
	provider.changed.connect(_terrain_changed)
	near_mesh = make_batch(true)
	far_mesh = make_batch(false)
	for index in mini(cameras.size(), 2):
		var camera := cameras[index]
		if not is_instance_valid(camera):
			continue
		var layer := first_view_layer if index == 0 else second_view_layer
		var layers := first_view_layer | second_view_layer
		var original := camera.cull_mask & layers
		camera.cull_mask = (camera.cull_mask & ~layers) | layer
		var trail := Trail.new()
		var near_material := make_material(trail, false)
		var far_material := make_material(trail, true)
		var distance := profile_distance()
		var radius := ceili(distance / TILE)
		var slots: Array[Array] = []
		for slot in (radius * 2 + 1) ** 2:
			slots.append([make_tile(near_mesh, near_material, layer), make_tile(far_mesh, far_material, layer)])
		views.append({"camera": camera, "mask": original, "trail": trail,
			"materials": [near_material, far_material], "slots": slots,
			"center": Vector2i(2147483647, 2147483647), "radius": radius})
	_process(0.0)

func _exit_tree() -> void:
	for view in views:
		if is_instance_valid(view.camera):
			var layers := first_view_layer | second_view_layer
			view.camera.cull_mask = (view.camera.cull_mask & ~layers) | int(view.mask)

func _terrain_changed() -> void:
	terrain_dirty = true

func draw_distance() -> float:
	return minf(profile_distance(), distance_cap)

func profile_distance() -> float:
	return clampf(profile.split_distance if cameras.size() > 1 else profile.view_distance, 24.0, 110.0)

func draw_density() -> float:
	return (profile.split_density if cameras.size() > 1 else profile.density) * density_multiplier

func set_detail(distance: float, density: float) -> void:
	distance_cap = clampf(distance, 24.0, 110.0)
	density_multiplier = clampf(density, 0.0, 1.0)
	for view in views:
		for material in view.materials:
			material.set_shader_parameter("fade_end", draw_distance())
			material.set_shader_parameter("density", draw_density())
		view.center = Vector2i(2147483647, 2147483647)

func make_material(trail: Trail, far: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("far_lod", far)
	material.set_shader_parameter("fade_end", draw_distance())
	material.set_shader_parameter("near_lod", NEAR_LOD)
	material.set_shader_parameter("far_lod_start", FAR_LOD)
	material.set_shader_parameter("density", draw_density())
	material.set_shader_parameter("seed", profile.seed)
	material.set_shader_parameter("blade_height", profile.height)
	material.set_shader_parameter("root_color", profile.root_color)
	material.set_shader_parameter("tip_color", profile.tip_color)
	material.set_shader_parameter("wind_strength", profile.wind)
	material.set_shader_parameter("trail_map", trail.texture)
	material.set_shader_parameter("trail_size", Trail.SIDE * Trail.STEP)
	return material

func make_tile(mesh: MultiMesh, material: ShaderMaterial, layer: int) -> MultiMeshInstance3D:
	var tile := MultiMeshInstance3D.new()
	tile.top_level = true
	tile.visible = false
	tile.layers = layer
	tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tile.multimesh = mesh
	tile.material_override = material
	add_child(tile)
	return tile

func make_batch(detailed: bool) -> MultiMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in (5 if detailed else 2):
		var direction := Vector3(cos(blade * 2.4), 0.0, sin(blade * 2.4))
		var side := direction.cross(Vector3.UP) * (0.045 if detailed else 0.08)
		var base := direction * (0.03 + blade * 0.035)
		var middle := base + Vector3.UP * 0.52 + direction * 0.055
		var tip := base + Vector3.UP * (0.82 + blade * 0.07) + direction * 0.19
		var vertices := [base - side, base + side, tip]
		if detailed:
			vertices = [base - side, base + side, middle + side * 0.6,
				base - side, middle + side * 0.6, middle - side * 0.6,
				middle - side * 0.6, middle + side * 0.6, tip]
		for vertex: Vector3 in vertices:
			surface.set_normal((Vector3.UP + direction * 0.35).normalized())
			surface.set_uv(Vector2(0, vertex.y))
			surface.add_vertex(vertex)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = surface.commit()
	batch.instance_count = ROWS * ROWS
	for index in batch.instance_count:
		var x := (float(index % ROWS) + 0.5) * TILE / ROWS
		var z := (floorf(float(index) / ROWS) + 0.5) * TILE / ROWS
		batch.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(x, 0.0, z)))
	return batch

func _process(delta: float) -> void:
	clock += delta
	var update_trails := clock - last_stamp >= Trail.INTERVAL
	var segments: Array = []
	if update_trails:
		last_stamp = clock
		segments = collect_segments()
	var refresh := terrain_dirty
	if refresh:
		ready_to_draw = true
		for view in views:
			for material in view.materials:
				var bound := provider.bind_material(material)
				ready_to_draw = ready_to_draw and bound
		terrain_dirty = not ready_to_draw
		var bounds := provider.height_range()
		var box := AABB(Vector3(-2, bounds.x - 2, -2), Vector3(TILE + 4, bounds.y - bounds.x + 6, TILE + 4))
		near_mesh.custom_aabb = box
		far_mesh.custom_aabb = box
	for view in views:
		if not is_instance_valid(view.camera) or not ready_to_draw:
			for pair in view.slots:
				pair[0].hide()
				pair[1].hide()
			continue
		var position_world: Vector3 = view.camera.global_position
		var eye := Vector2(position_world.x, position_world.z)
		var cell := Vector2i((eye / TILE).floor())
		for material in view.materials:
			material.set_shader_parameter("viewer", eye)
		if update_trails:
			view.trail.update(eye, segments, clock, profile.recovery_seconds)
			for material in view.materials:
				material.set_shader_parameter("trail_origin", Vector2(view.trail.origin) * Trail.STEP)
		if refresh or cell != view.center:
			assign_tiles(view, cell)

func candidate_instances() -> int:
	var count := 0
	for view in views:
		count += int(view.get("visible_batches", 0))
	return count * ROWS * ROWS

func assign_tiles(view: Dictionary, cell: Vector2i) -> void:
	view.center = cell
	var radius: int = view.radius
	var width := radius * 2 + 1
	var distance_limit := draw_distance()
	var count := 0
	# Conservative distances let batches cross LOD bands without CPU toggles mid-cell.
	var margin := TILE * sqrt(2.0)
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var key := cell + Vector2i(x, y)
			var start := Vector2(key) * TILE
			# Wrapping by world cell retains the slots in the overlapping area.
			var index := posmod(key.y, width) * width + posmod(key.x, width)
			var pair: Array = view.slots[index]
			var distance := Vector2(x, y).length() * TILE
			var eligible := distance <= distance_limit + margin and provider.covers_tile(Rect2(start, Vector2.ONE * TILE))
			var anchor := Vector3(start.x, 0.0, start.y)
			for tile in pair:
				if tile.position != anchor:
					tile.position = anchor
			pair[0].visible = eligible and distance <= FAR_LOD + margin
			pair[1].visible = eligible and distance >= NEAR_LOD - margin
			count += int(pair[0].visible) + int(pair[1].visible)
	view.visible_batches = count

func collect_segments() -> Array:
	var segments: Array = []
	var current: Dictionary[int, Vector2] = {}
	for item in get_tree().get_nodes_in_group(&"grass_interactors"):
		var interactor := item as Interactor
		if not interactor or not interactor.is_visible_in_tree() or segments.size() >= MAX_INTERACTORS:
			continue
		var point := Vector2(interactor.global_position.x, interactor.global_position.z)
		var id := interactor.get_instance_id()
		current[id] = point
		segments.append([previous.get(id, point), point, interactor.radius, interactor.strength])
	previous = current
	return segments
