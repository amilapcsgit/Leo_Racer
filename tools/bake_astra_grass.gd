extends SceneTree
## Run via tools/run_ultra_checks.py grass_bake.

var spacing := 1.0
const Bake := preload("res://addons/grass_field/grass_bake.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await game.initialization_finished
	var expected := "astra_coast"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--track="):
			expected = argument.trim_prefix("--track=")
	if game.chosen_track_id != expected:
		push_error("Cannot bake %s: loaded %s" % [expected, game.chosen_track_id])
		await game.quit_game(1)
		return
	var scenery: LeoTrackEnvironment = game.track_environment
	if scenery.sources.is_empty():
		push_error("Track support geometry unavailable")
		await game.quit_game(1)
		return
	spacing = 1.0 if scenery.track_id in ["astra_coast", "colombo_city"] else 2.0
	var atlas := bake(scenery)
	var output := "res://assets/tracks/grass_%s.res" % scenery.track_id
	var result := ResourceSaver.save(atlas, output, ResourceSaver.FLAG_COMPRESS)
	print(JSON.stringify({"status": "PASS" if result == OK else "FAIL", "output": output, "size": atlas.samples.get_size()}))
	atlas = null
	await game.quit_game(int(result != OK))

func bake(scenery: LeoTrackEnvironment) -> Bake:
	var bounds := Rect2()
	for point in scenery.circuit.points:
		bounds = bounds.expand(Vector2(point.x, point.z))
	bounds = bounds.grow(130.0)
	var origin := bounds.position.floor()
	var dimensions := Vector2i(((bounds.end - origin) / spacing).ceil())
	var heights := PackedFloat32Array()
	heights.resize(dimensions.x * dimensions.y)
	heights.fill(-INF)
	for entry in scenery.sources.values():
		var node: MeshInstance3D = entry.node
		var pose := node.global_transform
		var faces := node.mesh.get_faces()
		for index in range(0, faces.size(), 3):
			rasterize(pose * faces[index], pose * faces[index + 1], pose * faces[index + 2], origin, dimensions, heights)
	var water_heights := PackedFloat32Array()
	water_heights.resize(heights.size())
	water_heights.fill(-INF)
	for entry in scenery.water.values():
		var pose: Transform3D = entry.pose
		var faces: PackedVector3Array = entry.faces
		for index in range(0, faces.size(), 3):
			rasterize(pose * faces[index], pose * faces[index + 1], pose * faces[index + 2], origin, dimensions, water_heights)
	var paving := bake_paving(scenery.get_parent(), origin, dimensions)
	var image := Image.create_empty(dimensions.x, dimensions.y, false, Image.FORMAT_RGF)
	var elevation := Vector2(INF, -INF)
	var accepted := 0
	var paved_samples := 0
	var route_cells := {}
	for point: Vector3 in scenery.circuit.points:
		var center := Vector2i(floori(point.x / 32.), floori(point.z / 32.))
		for row in range(center.y - 5, center.y + 6):
			for column in range(center.x - 5, center.x + 6):
				route_cells[Vector2i(column, row)] = true
	var blocker_cells := {}
	for box: AABB in scenery.blockers.values():
		var expanded := box.grow(.48)
		var start := Vector2i(floori(expanded.position.x / 16.), floori(expanded.position.z / 16.))
		var end := Vector2i(floori(expanded.end.x / 16.), floori(expanded.end.z / 16.))
		for row in range(start.y, end.y + 1):
			for column in range(start.x, end.x + 1):
				var key := Vector2i(column, row)
				if not blocker_cells.has(key):
					blocker_cells[key] = []
				blocker_cells[key].append(box)
	for z in dimensions.y:
		for x in dimensions.x:
			var height := heights[z * dimensions.x + x]
			if not is_finite(height) or water_heights[z * dimensions.x + x] >= height - 0.14:
				continue
			if touches_paving(x, z, height, paving, dimensions):
				paved_samples += 1
				continue
			var xz := origin + (Vector2(x, z) + Vector2.ONE * 0.5) * spacing
			if not route_cells.has(Vector2i(floori(xz.x / 32.), floori(xz.y / 32.))):
				continue
			var point := Vector3(xz.x, height, xz.y)
			var blocker_key := Vector2i(floori(point.x / 16.), floori(point.z / 16.))
			var lane := scenery.circuit.project(point)
			var setback := absf(float(lane.offset)) - scenery.circuit.width_at(lane.distance) * 0.5
			if setback < 2.4 + spacing * 0.71 or setback > 125.0 or blocked(point, blocker_cells.get(blocker_key, [])):
				continue
			image.set_pixel(x, z, Color(height, 1.0, 0.0))
			elevation = Vector2(minf(elevation.x, height), maxf(elevation.y, height))
			accepted += 1
	assert(accepted > 0, "Track atlas has no eligible grass")
	print("Track grass raster accepted ", accepted, " samples and excluded ", paved_samples, " near paving")
	var atlas := Bake.new()
	atlas.samples = ImageTexture.create_from_image(image)
	atlas.origin = origin
	atlas.spacing = spacing
	atlas.elevation = elevation
	return atlas

func bake_paving(world: Node, origin: Vector2, dimensions: Vector2i) -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	heights.resize(dimensions.x * dimensions.y)
	heights.fill(-INF)
	for node: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
		if not node.mesh or node.mesh.get_surface_count() == 0:
			continue
		var material := node.get_active_material(0) as ShaderMaterial
		var paved := material and material.shader and material.shader.resource_path.ends_with("/paving_pbr.gdshader")
		if not paved and node.get_meta("surface_role", "") != "paving":
			continue
		var pose := node.global_transform
		var faces := node.mesh.get_faces()
		for index in range(0, faces.size(), 3):
			rasterize(pose * faces[index], pose * faces[index + 1], pose * faces[index + 2], origin, dimensions, heights)
	return heights

func touches_paving(x: int, z: int, ground: float, paving: PackedFloat32Array, dimensions: Vector2i) -> bool:
	# Neighboring texels allow for sample quantization and blade width.
	for row in range(maxi(z - 1, 0), mini(z + 2, dimensions.y)):
		for column in range(maxi(x - 1, 0), mini(x + 2, dimensions.x)):
			var height := paving[row * dimensions.x + column]
			if height >= ground - 0.25 and height <= ground + 1.3:
				return true
	return false

func rasterize(a: Vector3, b: Vector3, c: Vector3, origin: Vector2, dimensions: Vector2i, heights: PackedFloat32Array) -> void:
	if absf((b - a).cross(c - a).normalized().y) <= 0.83:
		return
	var av := (Vector2(a.x, a.z) - origin) / spacing - Vector2.ONE * 0.5
	var bv := (Vector2(b.x, b.z) - origin) / spacing - Vector2.ONE * 0.5
	var cv := (Vector2(c.x, c.z) - origin) / spacing - Vector2.ONE * 0.5
	var lower := Vector2i(av.min(bv).min(cv).ceil()).max(Vector2i.ZERO)
	var upper := Vector2i(av.max(bv).max(cv).floor()).min(dimensions - Vector2i.ONE)
	var ab := bv - av
	var ac := cv - av
	var area := ab.cross(ac)
	if is_zero_approx(area):
		return
	for z in range(lower.y, upper.y + 1):
		for x in range(lower.x, upper.x + 1):
			var point := Vector2(x, z) - av
			var u := point.cross(ac) / area
			var v := ab.cross(point) / area
			if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
				var index := z * dimensions.x + x
				heights[index] = maxf(heights[index], a.y + u * (b.y - a.y) + v * (c.y - a.y))


func blocked(point: Vector3, boxes: Array) -> bool:
	for box: AABB in boxes:
		var expanded := box.grow(.48)
		if point.x >= expanded.position.x and point.x <= expanded.end.x and point.z >= expanded.position.z and point.z <= expanded.end.z and point.y <= box.end.y and point.y + 1.2 >= box.position.y:
			return true
	return false
