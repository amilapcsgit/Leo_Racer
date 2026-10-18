class_name LeoCity
extends Node3D
## Deterministic, batched streetscape. Geometry lives outside the racing ribbon.

const MODEL_DIR := "res://assets/models/city/"
const PALETTE := [Color("ff957e"), Color("48c5c5"), Color("ffd16d"), Color("b59ae9"), Color("f4e0bc"), Color("eb77a7")]
const SHOP_NAMES := ["CEYLON TEA", "COAST CAFE", "LOTUS MARKET", "ISLAND SCOOPS", "MANGO & LIME", "COLOMBO CLUB", "PALM BAKERY", "OCEAN VIEW"]
const FACADE_MODELS := ["building-j", "building-a", "building-f", "building-e", "building-h", "building-k", "building-g", "building-i", "building-d", "building-l", "building-b", "building-n", "building-c"]

var circuit: LeoCircuit
var stats := {"buildings": 0, "skyline": 0, "props": 0, "batches": 0, "shop_signs": 0, "minimum_road_clearance": 999.0}
var _manifest: Dictionary
var _mesh_cache: Dictionary = {}
var _batches: Dictionary = {}
var _materials: Dictionary = {}
var _walls: Array[Material] = []
var art_profile: LeoArtProfile
var _plots: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

func setup(track: LeoCircuit, profile: LeoArtProfile=null) -> void:
	circuit = track
	art_profile = profile if profile else load("res://assets/config/colombo.tres")
	_rng.seed = 1082026
	_manifest = JSON.parse_string(FileAccess.get_file_as_string(MODEL_DIR + "manifest.json"))
	_make_materials()
	_sidewalks()
	_street_fronts(1.0)
	_street_fronts(-1.0)
	_background_blocks()
	_promenade()
	_garden()
	_festival_flags()
	_flush_batches()
	print("CITY_READY | buildings=%d | skyline=%d | props=%d | batches=%d | shops=%d | nearest_building_corner=%.2fm" % [stats.buildings, stats.skyline, stats.props, stats.batches, stats.shop_signs, stats.minimum_road_clearance])

func _make_materials() -> void:
	for color in art_profile.city_palette:
		var wall := ShaderMaterial.new()
		wall.shader = load("res://shaders/city_pbr.gdshader")
		wall.set_shader_parameter("tint",color)
		wall.set_shader_parameter("concrete_color",load("res://assets/materials/Concrete034_2K-JPG_Color.jpg"))
		wall.set_shader_parameter("concrete_normal",load("res://assets/materials/Concrete034_2K-JPG_NormalGL.jpg"))
		_walls.append(wall)
	var detail := StandardMaterial3D.new()
	detail.vertex_color_use_as_albedo = true
	detail.roughness = .66
	_materials["city_detail"] = detail
	var glass := StandardMaterial3D.new()
	glass.vertex_color_use_as_albedo = true
	glass.albedo_color = Color("35616b")
	glass.roughness = .16
	glass.metallic = .68
	_materials["city_glass"] = glass
	for entry in [["paving", "decbaa"], ["paving_light", "f0d9b4"], ["cream", "ffedcc"], ["terracotta", "cb6f4b"], ["wood", "77482e"], ["iron", "264b50"], ["leaf", "27854c"], ["leaf_light", "68b849"], ["leaf_dark", "1f623d"], ["pink", "fa4b92"], ["mango", "ffba31"], ["aqua", "26d6ce"], ["coral", "fb7468"], ["violet", "a789e4"]]:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(entry[1])
		material.roughness = .8
		_materials[entry[0]] = material
	var lantern := StandardMaterial3D.new()
	lantern.albedo_color = Color("fff1ad")
	lantern.emission_enabled = true
	lantern.emission = Color("ffc860")
	lantern.emission_energy_multiplier = .75
	_materials["lantern"] = lantern
	_materials["paving"] = LeoColomboWorld.pbr_material("res://shaders/paving_pbr.gdshader","PavingStones001")

func _sidewalks() -> void:
	# Separate ribbons follow the true sampled circuit, with no coplanar faces.
	for side in [-1.0, 1.0]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(circuit.points.size()):
			var a := float(i) * circuit.step
			var b := float(i + 1) * circuit.step
			var v0 := circuit.sample(a, side * 11.45) + Vector3.UP * .085
			var v1 := circuit.sample(a, side * 21.3) + Vector3.UP * .085
			var v2 := circuit.sample(b, side * 21.3) + Vector3.UP * .085
			var v3 := circuit.sample(b, side * 11.45) + Vector3.UP * .085
			for v in [v0, v1, v2, v0, v2, v3]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
		var path := MeshInstance3D.new()
		path.mesh = st.commit()
		path.material_override = _materials.paving
		path.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(path)
	# Cross-joints and a second row of inset pavers break up the broad walkway.
	for i in range(int(circuit.length / 3.0)):
		var s := i * 3.0
		var tangent := circuit.direction(s)
		var basis0 := Basis(Vector3.UP, atan2(tangent.x, tangent.z))
		for side in [-1.0, 1.0]:
			_box(circuit.sample(s, side * 16.3) + Vector3.UP * .10, Vector3(9.4, .025, .075), basis0, "paving_light")
			_box(circuit.sample(s, side * 12.2) + Vector3.UP * .12, Vector3(.55, .055, 2.8), basis0, "cream")

func _street_fronts(side: float) -> void:
	var s := 7.0 if side > 0.0 else 15.0
	var index := 0
	while s < circuit.length:
		var model_name: String = FACADE_MODELS[index % FACADE_MODELS.size()]
		var info: Dictionary = _manifest[model_name]
		var scale0 := .87 + .065 * float(index % 4)
		var width := float(info.width) * scale0
		var depth := float(info.depth) * scale0
		var normal := Vector3(-circuit.direction(s).z, 0, circuit.direction(s).x)
		var front := -normal * side
		var rot := Basis(Vector3.UP, atan2(front.x, front.z))
		var pos := circuit.sample(s, side * (22.7 + depth * .5))
		# The sea-facing western promenade is kept open to the water.
		var coastal := side < 0.0 and pos.x < -76.0
		if not coastal and _plot_is_clear(pos, rot, width, depth):
			_place_model(model_name, pos, rot, Vector3.ONE * scale0, index % PALETTE.size())
			_register_plot(pos, rot, width, depth)
			stats.buildings += 1
			_shopfront(s, side, width, index, rot)
		index += 1
		s += width + 2.7

func _plot_is_clear(pos: Vector3, rot: Basis, width: float, depth: float) -> bool:
	if pos.x - width * .5 < -116.0:
		return false
	var half := Vector2(width * .5 + .6, depth * .5 + .6)
	for xx in [-1.0, 1.0]:
		for zz in [-1.0, 1.0]:
			var corner: Vector3 = pos + rot.x * half.x * xx + rot.z * half.y * zz
			var road: Dictionary = circuit.project(corner)
			if corner.distance_to(road.center) < 14.2:
				return false
	# A small gap between oriented footprints prevents facades intersecting.
	var axes: Array[Vector2] = [Vector2(rot.x.x, rot.x.z), Vector2(rot.z.x, rot.z.z)]
	for other in _plots:
		var delta := Vector2(pos.x, pos.z) - Vector2(other.pos.x, other.pos.z)
		var separate := false
		var other_axes: Array = other.axes
		for axis in axes + other_axes:
			var radius := absf(axes[0].dot(axis)) * half.x + absf(axes[1].dot(axis)) * half.y
			var other_radius: float = absf(other_axes[0].dot(axis)) * other.half.x + absf(other_axes[1].dot(axis)) * other.half.y
			if absf(delta.dot(axis)) > radius + other_radius:
				separate = true
				break
		if not separate:
			return false
	# Protect the existing pavilion and Lotus garden from new buildings.
	if absf(pos.x) < 33.0 and pos.z > 13.0 and pos.z < 54.0:
		return false
	if Vector2(pos.x, pos.z + 25.0).length() < 40.0:
		return false
	return true

func _register_plot(pos: Vector3, rot: Basis, width: float, depth: float) -> void:
	_plots.append({"pos": pos, "axes": [Vector2(rot.x.x, rot.x.z), Vector2(rot.z.x, rot.z.z)], "half": Vector2(width * .5 + .6, depth * .5 + .6)})
	for xx in [-1.0, 1.0]:
		for zz in [-1.0, 1.0]:
			var corner: Vector3 = pos + rot.x * width * .5 * xx + rot.z * depth * .5 * zz
			var road: Dictionary = circuit.project(corner)
			stats.minimum_road_clearance = minf(stats.minimum_road_clearance, corner.distance_to(road.center))

func _shopfront(s: float, side: float, width: float, index: int, rot: Basis) -> void:
	var front := rot.z
	var point := circuit.sample(s, side * 22.4)
	# Striped valances, projecting signs, planted tubs and outdoor cafe seating.
	var awning_width := minf(width * .85, 12.5)
	for j in range(int(awning_width / .65)):
		var local_x := (float(j) + .5) * .65 - awning_width * .5
		var p := point + rot.x * local_x + front * .8 + Vector3.UP * 3.3
		var color: String = ["aqua", "coral", "mango", "violet", "pink"][index % 5] if j % 2 == 0 else "cream"
		_box(p, Vector3(.65, .14, 2.1), rot.rotated(rot.x, -.14), color)
		_box(p + front * 1.0 - Vector3.UP * .18, Vector3(.65, .35, .08), rot, color)
	_box(point + Vector3.UP * 4.0, Vector3(awning_width + .4, .95, .20), rot, "iron")
	var text := TextMesh.new()
	text.text = SHOP_NAMES[index % SHOP_NAMES.size()]
	text.font_size = 40
	text.pixel_size = minf(.022, (awning_width - .4) / (float(text.text.length()) * 24.0))
	text.depth = .015
	var label := MeshInstance3D.new()
	label.mesh = text
	label.material_override = _materials.cream
	label.position = point + Vector3.UP * 4.0 + front * .135
	label.basis = rot
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label)
	stats.shop_signs += 1
	for xx in [-1.0, 1.0]:
		_planter(point + rot.x * (width * .40) * xx + front * 2.9, rot, index)
	if index % 3 == 0:
		var cafe_pos := point + front * 3.9 + rot.x * 1.1
		_place_model("detail-parasol-a" if index % 2 == 0 else "detail-parasol-b", cafe_pos, rot, Vector3.ONE * .69, index % PALETTE.size())
		_cylinder(cafe_pos + Vector3.UP * .8, .68, .14, "cream")
		_cylinder(cafe_pos + Vector3.UP * .4, .09, .8, "iron")
		for xx in [-1.0, 1.0]:
			_box(cafe_pos + rot.x * .95 * xx + Vector3.UP * .43, Vector3(.5, .12, .5), rot, "coral")
			_box(cafe_pos + rot.x * .95 * xx + Vector3.UP * .23, Vector3(.09, .4, .09), rot, "iron")

func _background_blocks() -> void:
	# Two skyline layers make the city read beyond the trackside buildings.
	for i in range(34):
		var angle := -.60 + float(i) / 33.0 * 4.1
		var radius := 165.0 + float(i % 3) * 27.0
		var pos := Vector3(28.0 + sin(angle) * radius, 0, -22.0 - cos(angle) * radius)
		if pos.x < -75.0:
			continue
		var model_name := "building-skyscraper-" + char(97 + i % 5)
		var rot := Basis(Vector3.UP, atan2(-pos.x, -pos.z))
		var scale0 := .90 + .15 * float(i % 4)
		var info: Dictionary = _manifest[model_name]
		if _plot_is_clear(pos, rot, float(info.width) * scale0, float(info.depth) * scale0):
			_place_model(model_name, pos, rot, Vector3(1.0, 1.15 + .18 * float(i % 3), 1.0) * scale0, 4 if i % 3 == 0 else i % PALETTE.size())
			_register_plot(pos, rot, float(info.width) * scale0, float(info.depth) * scale0)
			stats.skyline += 1
	for i in range(25):
		var s := float(i) * circuit.length / 25.0 + 9.0
		var pos := circuit.sample(s, -52.0)
		if pos.x < -77.0:
			continue
		var model_name: String = ["building-i", "building-m", "building-l", "building-n"][i % 4]
		var info: Dictionary = _manifest[model_name]
		var normal := Vector3(-circuit.direction(s).z, 0, circuit.direction(s).x)
		var rot := Basis(Vector3.UP, atan2(normal.x, normal.z))
		if _plot_is_clear(pos, rot, float(info.width), float(info.depth)):
			_place_model(model_name, pos, rot, Vector3.ONE, (i + 2) % PALETTE.size())
			_register_plot(pos, rot, float(info.width), float(info.depth))
			stats.buildings += 1

func _promenade() -> void:
	for i in range(int(circuit.length / 16.0)):
		var s := float(i) * 16.0 + 6.0
		var tangent := circuit.direction(s)
		var rot := Basis(Vector3.UP, atan2(tangent.x, tangent.z))
		for side in [-1.0, 1.0]:
			var p := circuit.sample(s, side * 18.8)
			if i % 2 == 0:
				_bench(p, rot)
			else:
				_planter(p, rot, i)
		# Inland lanterns complement the existing promenade banner lamps.
		var lamp := circuit.sample(s, 12.8)
		_cylinder(lamp + Vector3.UP * 2.6, .10, 5.2, "iron")
		_cylinder(lamp + Vector3.UP * .17, .26, .34, "cream")
		_box(lamp + Vector3.UP * 5.3, Vector3(.70, .15, .7), rot, "iron")
		_box(lamp + Vector3.UP * 5.0, Vector3(.45, .53, .45), rot, "lantern")
		_box(lamp + Vector3.UP * 4.63, Vector3(.65, .13, .65), rot, "iron")
		if i % 3 == 0:
			var tree_pos := circuit.sample(s + 7.0, 19.5)
			_tree(tree_pos, 4.5 + float(i % 4) * .5)
	# Continuous stone balustrade beside the beach, with open ocean beyond.
	for i in range(58):
		var p := Vector3(-120.0, .65, -180.0 + float(i) * 6.2)
		_box(p, Vector3(.65, 1.3, .8), Basis.IDENTITY, "cream")
		_box(p + Vector3(0, .75, 0), Vector3(1.0, .18, 1.1), Basis.IDENTITY, "cream")
		_box(p + Vector3(0, .48, 3.1), Vector3(.35, .20, 6.2), Basis.IDENTITY, "cream")
		_box(p + Vector3(0, -.10, 3.1), Vector3(.28, .13, 6.2), Basis.IDENTITY, "cream")
	for i in range(18):
		var p := Vector3(-126.0 + float(i % 2) * -3.0, .1, -145.0 + float(i) * 17.0)
		_place_model("detail-parasol-b", p, Basis(Vector3.UP, float(i) * .5), Vector3.ONE * .65, i % PALETTE.size())
		_box(p + Vector3(.8, .20, .4), Vector3(.65, .18, 1.7), Basis.IDENTITY, "coral" if i % 2 == 0 else "aqua")

func _garden() -> void:
	# Flowering tropical canopies frame the existing Independence pavilion.
	for i in range(22):
		var angle := float(i) * TAU / 22.0
		var p := Vector3(cos(angle) * 43.0, 0, -25.0 + sin(angle) * 43.0)
		var road: Dictionary = circuit.project(p)
		if p.distance_to(road.center) > 20.0 and not (absf(p.x)<29.0 and p.z>15.0):
			_tree(p, 5.0 + float(i % 4))
	for i in range(16):
		var angle := float(i) * TAU / 16.0
		var p := Vector3(cos(angle) * 24.8, .1, -25.0 + sin(angle) * 24.8)
		_planter(p, Basis(Vector3.UP, -angle), i)
	for x in [-30.0, 30.0]:
		for z in [22.0, 34.0, 46.0]:
			_bench(Vector3(x, .1, z), Basis(Vector3.UP, PI * .5))

func _festival_flags() -> void:
	var colors: Array[String] = ["pink", "mango", "aqua", "cream", "coral", "violet"]
	var flag_vertices: Dictionary = {}
	for color in colors:
		flag_vertices[color] = PackedVector3Array()
	for i in range(10):
		var s := 31.0 + float(i) * 71.0
		var tangent := circuit.direction(s)
		var right := Vector3(-tangent.z, 0, tangent.x)
		var center := circuit.sample(s)
		for side in [-1.0, 1.0]:
			_cylinder(center + right * side * 12.7 + Vector3.UP * 4.6, .075, 9.2, "cream")
		for j in range(22):
			var x := -12.5 + float(j) * 1.15
			var sag := sin((x + 12.7) / 25.4 * PI) * 1.25
			var a := center + right * x + Vector3.UP * (9.0 - sag)
			var b := a + right * .73
			var c := a + right * .365 - Vector3.UP * .88
			_box(a + right * .57 + Vector3.UP * .025, Vector3(1.18, .035, .035), Basis(right, Vector3.UP, right.cross(Vector3.UP)), "iron")
			var key: String = colors[(i + j) % colors.size()]
			var verts: PackedVector3Array = flag_vertices[key]
			verts.append_array(PackedVector3Array([a, b, c, c, b, a]))
			flag_vertices[key] = verts
	for color in colors:
		var verts: PackedVector3Array = flag_vertices[color]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in verts:
			st.add_vertex(v)
		st.generate_normals()
		var flags := MeshInstance3D.new()
		flags.mesh = st.commit()
		flags.material_override = _materials[color]
		flags.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flags)

func _tree(p: Vector3, height: float) -> void:
	# Replace primitive canopy props with baked EZ Tree foliage; core assets stay intact.
	var variant := int(height)%3
	var mesh: Mesh = load("res://assets/models/colombo/shade_tree_%d.res"%variant)
	_queue("ez_shade_%d"%variant,mesh,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*height/14.0),p),true)
	return

func _planter(p: Vector3, rot: Basis, index: int) -> void:
	_box(p + Vector3.UP * .35, Vector3(2.1, .7, 1.15), rot, "terracotta")
	_box(p + Vector3.UP * .73, Vector3(2.3, .14, 1.3), rot, "cream")
	for j in range(3):
		var q := p + rot.x * (float(j) - 1.0) * .62 + Vector3.UP * .94
		_sphere(q, Vector3(.65, .48, .61), "leaf" if j % 2 == 0 else "leaf_light")
		for k in range(3):
			_sphere(q + Vector3(.26 * cos(float(k) * TAU / 3.0), .43, .23 * sin(float(k) * TAU / 3.0)), Vector3.ONE * .15, "pink" if index % 2 == 0 else "mango")

func _bench(p: Vector3, rot: Basis) -> void:
	for side in [-1.0, 1.0]:
		_box(p + rot.x * side * 1.05 + Vector3.UP * .37, Vector3(.15, .74, .8), rot, "iron")
	for j in range(4):
		_box(p + rot.z * (float(j) - 1.5) * .22 + Vector3.UP * .73, Vector3(2.7, .11, .17), rot, "wood")
	for j in range(3):
		_box(p + rot.z * .49 + Vector3.UP * (1.0 + float(j) * .19), Vector3(2.7, .15, .1), rot, "wood")

func _place_model(model_name: String, pos: Vector3, rot: Basis, scale0: Vector3, palette: int) -> void:
	var key := model_name + "_" + str(palette)
	if not _mesh_cache.has(key):
		var scene: Node3D = load(MODEL_DIR + model_name + ".glb").instantiate()
		var original := _find_mesh(scene)
		if original == null:
			push_error("City mesh missing: " + model_name)
			scene.free()
			return
		var mesh: ArrayMesh = original.mesh.duplicate()
		for surface in range(mesh.get_surface_count()):
			var material: Material = mesh.surface_get_material(surface)
			if material.resource_name.contains("Wall"):
				mesh.surface_set_material(surface, _walls[palette])
			elif material.resource_name.contains("Glass"):
				mesh.surface_set_material(surface, _materials.city_glass)
			else:
				mesh.surface_set_material(surface, _materials.city_detail)
		_mesh_cache[key] = mesh
		scene.free()
	# Kenney storefront doors face -Z. City sign/awning frames face +Z.
	var model_rot := rot.rotated(Vector3.UP, PI) if model_name.begins_with("building") else rot
	_queue(key, _mesh_cache[key], Transform3D(model_rot.scaled(scale0), pos), true)

func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var result := _find_mesh(child)
		if result != null:
			return result
	return null

func _box(pos: Vector3, size0: Vector3, rot: Basis, material: String) -> void:
	var key := "box_" + material
	if not _mesh_cache.has(key):
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		mesh.material = _materials[material]
		_mesh_cache[key] = mesh
	_queue(key, _mesh_cache[key], Transform3D(rot.scaled_local(size0), pos), false)

func _sphere(pos: Vector3, size0: Vector3, material: String) -> void:
	var key := "sphere_" + material
	if not _mesh_cache.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 12
		mesh.rings = 6
		mesh.material = _materials[material]
		_mesh_cache[key] = mesh
	_queue(key, _mesh_cache[key], Transform3D(Basis.IDENTITY.scaled(size0), pos), false)

func _cylinder(pos: Vector3, radius: float, height: float, material: String) -> void:
	var key := "cylinder_" + material
	if not _mesh_cache.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = 1.0
		mesh.bottom_radius = 1.0
		mesh.height = 1.0
		mesh.radial_segments = 10
		mesh.material = _materials[material]
		_mesh_cache[key] = mesh
	_queue(key, _mesh_cache[key], Transform3D(Basis.IDENTITY.scaled(Vector3(radius, height, radius)), pos), false)

func _queue(key: String, mesh: Mesh, transform0: Transform3D, shadows: bool) -> void:
	if not _batches.has(key):
		_batches[key] = {"mesh": mesh, "transforms": [], "shadows": shadows}
	_batches[key].transforms.append(transform0)
	stats.props += 1

func _flush_batches() -> void:
	for key in _batches:
		var batch: Dictionary = _batches[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = batch.mesh
		mm.instance_count = batch.transforms.size()
		for i in range(mm.instance_count):
			mm.set_instance_transform(i, batch.transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.name = "City_" + key
		instance.multimesh = mm
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if batch.shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visibility_range_end = 570.0
		instance.visibility_range_end_margin = 30.0
		add_child(instance)
	stats.batches = _batches.size()
	_batches.clear()
