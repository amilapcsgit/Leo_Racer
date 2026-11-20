class_name LeoTrackEnvironment
extends Node3D

const TILE := 24.0
const RADII := [42.0, 66.0, 90.0]
const COUNTS := [44, 100, 190]
const WATER := preload("res://shaders/environment_water.gdshader")
const GRASS := preload("res://shaders/environment_grass.gdshader")

var game: Node3D
var circuit: LeoCircuit
var track_id: String
var tier := 0
var manual := 0
var ceiling := 2
var elapsed := 0.0
var window: Array[float] = []
var below_budget := 0
var above_budget := 0
var settled := 0.0
var grass_mesh: ArrayMesh
var grass_material: ShaderMaterial
var sources := {}
var blockers := {}
var water := {}
var tiles := {}
var pending: Array[Vector2i] = []
var wanted := {}
var last_centers: Array[Vector3] = []
var last_frame_us := 0

func configure(owner_game: Node3D) -> void:
	game = owner_game
	circuit = game.circuit
	track_id = String(game.track_definition.id)
	name = "TrackEnvironment"
	grass_material = ShaderMaterial.new()
	grass_material.shader = GRASS
	var palette: Array = {
		"astra_coast": ["5b6530","96934b",.36],
		"colombo_city": ["314c22","687a36",.21],
		"kandy_lake": ["324c22","74864a",.46],
		"wennappuwa": ["3b5127","85954c",.41]
	}.get(track_id, ["3b5127","829045",.36])
	grass_material.set_shader_parameter("low_color", Color(palette[0]))
	grass_material.set_shader_parameter("high_color", Color(palette[1]))
	grass_mesh = blades(float(palette[2]))
	grass_mesh.surface_set_material(0, grass_material)

func _ready() -> void:
	for node in get_parent().find_children("*", "MeshInstance3D", true, false):
		register(node)
	get_tree().node_added.connect(on_node_added)

func on_node_added(node: Node) -> void:
	if node is MeshInstance3D and get_parent() and get_parent().is_ancestor_of(node):
		register.call_deferred(node)

func register(node: MeshInstance3D) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree() or not node.mesh:
		return
	var id := node.get_instance_id()
	var role := String(node.get_meta("surface_role", ""))
	var name_text := String(node.name)
	var material := node.get_active_material(0) as ShaderMaterial if node.mesh.get_surface_count() else null
	var code := material.shader.code if material and material.shader else ""
	var box := node.global_transform * node.get_aabb()
	if role == "water" or name_text in ["IndianOcean", "LotusLagoon", "BeiraInspiredLake", "KandyLakeColomboWater"] or (code.contains("uniform bool ocean") and code.contains("lake_radius")):
		var updated := ShaderMaterial.new()
		updated.shader = WATER
		var ocean: bool = name_text == "IndianOcean" or (material and material.get_shader_parameter("ocean") == true)
		var shore_mode := 1 if ocean else 2
		if track_id == "astra_coast":
			updated.set_shader_parameter("coast_x", -145.0)
		elif material:
			for field in ["coast_x","lake_center","deep_color","shallow_color","shore_distance","shore_origin","shore_extent"]:
				var value: Variant = material.get_shader_parameter(field)
				if value != null: updated.set_shader_parameter(field, value)
			var radius: Variant = material.get_shader_parameter("lake_radius")
			if radius is float and radius > 0.0:
				updated.set_shader_parameter("lake_extent",Vector2.ONE*radius)
			if material.get_shader_parameter("shaped_shoreline") == true and material.get_shader_parameter("shore_distance"):
				shore_mode = 3
		updated.set_shader_parameter("ocean", ocean)
		updated.set_shader_parameter("shore_mode", shore_mode)
		updated.set_shader_parameter("detail", tier)
		node.material_override = updated
		water[id] = {"material": updated, "bounds": box, "faces": node.mesh.get_faces(), "pose": node.global_transform, "plane": node.mesh is PlaneMesh}
	elif role in ["terrain_verge","terrain_detail","terrain_backdrop"] or name_text.begins_with("SculptedAstra") or code.contains("hint_normal") and (code.contains("ground_normal") or code.contains("uv=world.xz*.45")):
		if role != "terrain_backdrop":
			sources[id] = {"node": node, "bounds": box}
		if code.contains("uniform sampler2D ground_albedo"):
			material.set_shader_parameter("terrain_palette", Vector3(1.12,.98,.70) if track_id == "astra_coast" else Vector3(1.0,1.06,.93))
	elif box.size.x >= .65 and box.size.z >= .4 and box.size.x < 100. and box.size.z < 100. and (box.size.y > 1.3 or role in ["landmark_ground","paving"] or "pav" in name_text.to_lower()):
		blockers[id] = box
	else:
		return
	node.tree_exiting.connect(func():
		sources.erase(id)
		blockers.erase(id)
		water.erase(id)
		if role.begins_with("terrain_"): invalidate(box), CONNECT_ONE_SHOT)
	if sources.has(id): invalidate(box)

func invalidate(box: AABB) -> void:
	for key in tiles.keys():
		if covers(box.grow(TILE*.6), center(key)):
			tiles[key].queue_free()
			tiles.erase(key)
			if wanted.has(key) and not pending.has(key): pending.append(key)

func set_quality(setting: int, preset: int, split: bool) -> void:
	var limit := clampi(preset, 0, 2) if setting == 0 else 2
	var forward := RenderingServer.get_current_rendering_method() == "forward_plus"
	if split and not forward: limit = mini(limit, 1)
	if setting == manual and limit == ceiling and settled > 0.: return
	manual = setting
	ceiling = limit
	window.clear()
	below_budget = 0
	above_budget = 0
	settled = 0.
	change_tier(mini(setting - 1 if setting > 0 else int(forward and not split), ceiling))

func change_tier(value: int) -> void:
	tier = value
	grass_material.set_shader_parameter("detail", tier)
	for entry in water.values(): entry.material.set_shader_parameter("detail",tier)
	for tile in tiles.values():
		tile.multimesh.visible_instance_count = mini(tile.multimesh.instance_count, COUNTS[tier])
		tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if tier == 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	refresh_wanted()

func tick_quality(dt: float) -> void:
	if manual > 0 or game.state != "race" or not get_window().has_focus():
		if game.state != "race":
			window.clear()
			settled = 0.
			above_budget = 0
			below_budget = 0
		return
	settled += dt
	if settled < 4.: return
	window.append(minf(dt*1000., 60.))
	if window.size() < 120: return
	window.sort()
	var frame_ms := window[107]
	window.clear()
	apply_window(frame_ms)

func apply_window(frame_ms: float) -> void:
	below_budget = below_budget + 1 if frame_ms > 18.0 else 0
	above_budget = above_budget + 1 if frame_ms < 16.95 else 0
	if below_budget >= 2 and tier > 0:
		change_tier(tier - 1)
		below_budget = 0
		above_budget = -8
	elif above_budget >= 8 and tier < ceiling:
		change_tier(tier + 1)
		above_budget = 0

func _process(dt: float) -> void:
	var now := Time.get_ticks_usec()
	if last_frame_us > 0: tick_quality((now-last_frame_us)/1000000.)
	last_frame_us = now
	elapsed += dt
	if elapsed > .32:
		elapsed = 0.
		refresh_wanted()
	if not pending.is_empty():
		var key: Vector2i = pending.pop_front()
		if wanted.has(key) and not tiles.has(key): build_tile(key)

func center(key: Vector2i) -> Vector3:
	return Vector3((key.x+.5)*TILE,0.,(key.y+.5)*TILE)

func covers(box: AABB, point: Vector3) -> bool:
	return point.x >= box.position.x and point.x <= box.end.x and point.z >= box.position.z and point.z <= box.end.z

func refresh_wanted() -> void:
	if not is_inside_tree(): return
	last_centers.clear()
	for slot in game.human_count:
		if slot >= game.local_players.size(): break
		var kart: Variant = game.local_players[slot].kart
		if is_instance_valid(kart): last_centers.append(kart.global_position)
	if last_centers.is_empty(): last_centers.append(circuit.sample(0.))
	var radius: float = RADII[tier]
	wanted.clear()
	for eye in last_centers:
		var middle := Vector2i(floori(eye.x/TILE),floori(eye.z/TILE))
		var steps := ceili(radius/TILE)
		for x in range(-steps, steps+1):
			for z in range(-steps, steps+1):
				var key := middle + Vector2i(x,z)
				var at := center(key)
				var distance := Vector2(eye.x-at.x,eye.z-at.z).length()
				if distance < radius: wanted[key] = minf(distance,wanted.get(key,INF))
	for key in tiles.keys():
		if not wanted.has(key):
			tiles[key].queue_free()
			tiles.erase(key)
	pending.clear()
	for key in wanted:
		if not tiles.has(key): pending.append(key)
	pending.sort_custom(func(a,b):return wanted[a]<wanted[b])

func build_tile(key: Vector2i) -> void:
	var at := center(key)
	var area := AABB(at - Vector3(TILE*.5,1000.,TILE*.5),Vector3(TILE,2000.,TILE))
	var supports: Array = []
	for entry in sources.values():
		if not entry.bounds.intersects(area): continue
		if not entry.has("faces"):
			var node: MeshInstance3D = entry.node
			entry.faces = node.mesh.get_faces()
			entry.pose = node.global_transform
		var faces: PackedVector3Array = entry.faces
		var pose: Transform3D = entry.pose
		for i in range(0,faces.size(),3):
			var a := pose * faces[i]
			var b := pose * faces[i+1]
			var c := pose * faces[i+2]
			if minf(a.x,minf(b.x,c.x)) > area.end.x or maxf(a.x,maxf(b.x,c.x)) < area.position.x or minf(a.z,minf(b.z,c.z)) > area.end.z or maxf(a.z,maxf(b.z,c.z)) < area.position.z: continue
			var normal := (b-a).cross(c-a).normalized()
			if absf(normal.y) > .83: supports.append([a,b,c])
	var exclusions: Array = []
	for box in blockers.values():
		if box.intersects(area): exclusions.append(box)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(key.x, track_id.hash(), key.y))
	var transforms: Array[Transform3D] = []
	if not supports.is_empty():
		for i in 320:
			if transforms.size() >= COUNTS[2]: break
			var horizontal := Vector3(at.x+rng.randf_range(-TILE*.5,TILE*.5), 0., at.z+rng.randf_range(-TILE*.5,TILE*.5))
			var height := -INF
			for face in supports:
				var hit: Variant = Geometry3D.segment_intersects_triangle(horizontal+Vector3.UP*800.,horizontal-Vector3.UP*30.,face[0],face[1],face[2])
				if hit is Vector3: height = maxf(height,hit.y)
			if not is_finite(height): continue
			horizontal.y = height
			var lane := circuit.project(horizontal)
			var setback := absf(float(lane.offset))-circuit.width_at(float(lane.distance))*.5
			var verge := 8.3 if track_id in ["kandy_lake","colombo_city"] else 2.4
			if setback < verge or setback > 125. or occupied(horizontal,exclusions): continue
			var size := rng.randf_range(.62,1.45)
			transforms.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size),horizontal-Vector3.UP*.025))
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = grass_mesh
	batch.multimesh.instance_count = transforms.size()
	for i in transforms.size(): batch.multimesh.set_instance_transform(i,transforms[i])
	batch.multimesh.custom_aabb = AABB(Vector3(area.position.x,-2.,area.position.z),Vector3(TILE,9.,TILE))
	if not transforms.is_empty():
		var bounds := AABB(transforms[0].origin, Vector3.ZERO)
		for transform in transforms: bounds = bounds.expand(transform.origin)
		batch.multimesh.custom_aabb = bounds.grow(1.3)
	batch.multimesh.visible_instance_count = mini(transforms.size(), COUNTS[tier])
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if tier == 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)
	tiles[key] = batch

func occupied(point: Vector3, exclusions: Array) -> bool:
	for box in exclusions:
		if covers(box.grow(.48),point) and point.y <= box.end.y and point.y+1.2 >= box.position.y: return true
	for entry in water.values():
		if not covers(entry.bounds,point) or point.y > entry.bounds.end.y+.14: continue
		if entry.plane: return true
		var f: PackedVector3Array = entry.faces
		var pose: Transform3D = entry.pose
		for i in range(0,f.size(),3):
			if Geometry3D.segment_intersects_triangle(point+Vector3.UP*5.,point-Vector3.UP,pose*f[i],pose*f[i+1],pose*f[i+2]) is Vector3: return true
	return false

func blades(height: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 7:
		var direction := Vector3(cos(i*2.4),0.,sin(i*2.4))
		var foot := direction * (.04+.029*i)
		var cross := direction.cross(Vector3.UP) * (.04+.008*(i%3))
		var blade_height := height * (.62+.065*i)
		for vertex in [[foot-cross,0.],[foot+cross,0.],[foot+Vector3.UP*blade_height+direction*.13,1.]]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(0.,vertex[1]))
			surface.add_vertex(vertex[0])
	return surface.commit()
