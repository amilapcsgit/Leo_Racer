extends Node3D

const Field := preload("../grass_field.gd")
const TerrainProvider := preload("../grass_terrain3d_provider.gd")
const Interactor := preload("../grass_interactor.gd")
const Trail := preload("../grass_trail.gd")
const STOCK := "res://addons/terrain_3d/extras/particle_example/Terrain3DParticles.tscn"
const REGION := 256
const SPEED := 66.0
const START := -470.0
const FINISH := 900.0

var camera: Camera3D
var vehicle: Node3D
var distance := START
var field: Field
var qa_output := ""
var qa_phase := 0
var qa_frames := 0
var qa_views := 0
var qa_first_tiles: Array[Vector3] = []

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--grass-demo-output="):
			qa_output = argument.trim_prefix("--grass-demo-output=")
	if not ClassDB.class_exists("Terrain3D"):
		push_error("Install Terrain3D 1.1.0 to run the grass demo.")
		get_tree().quit(2)
		return
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-43, -25, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	var ambient := Environment.new()
	ambient.background_mode = Environment.BG_SKY
	ambient.sky = sky
	var world_environment := WorldEnvironment.new()
	world_environment.environment = ambient
	add_child(world_environment)
	camera = Camera3D.new()
	camera.far = 600.0
	add_child(camera)
	camera.make_current()
	vehicle = Node3D.new()
	add_child(vehicle)
	for offset in [-0.75, 0.75]:
		var wheel := Interactor.new()
		wheel.position.z = offset
		wheel.radius = 0.6
		vehicle.add_child(wheel)
	move_view()
	var terrain := ClassDB.instantiate("Terrain3D") as Node3D
	terrain.set("region_size", REGION)
	# The camera follows a scripted path through holes and missing regions.
	terrain.set("collision_mode", 0)
	terrain.set("free_editor_textures", false)
	add_child(terrain)
	terrain.call("set_camera", camera)
	var data: Object = terrain.get("data")
	for z in range(-1, 2):
		for x in range(-2, 4):
			if Vector2i(x, z) != Vector2i(2, 1):
				build_region(data, Vector2i(x, z))
	data.call("calc_height_range", true)
	data.call("update_maps")
	install_textures(terrain)
	if not qa_output.is_empty() and not (verify_fixture(data) and verify_trail()):
		get_tree().quit(1)
		return
	if "--stock-grass" in OS.get_cmdline_user_args():
		if not ResourceLoader.exists(STOCK):
			push_error("The Terrain3D 1.1.0 particle example is missing.")
			get_tree().quit(2)
			return
		var stock: Node3D = load(STOCK).instantiate()
		terrain.add_child(stock)
	else:
		field = Field.new()
		field.profile.root_color = Color("4b592e")
		field.profile.tip_color = Color("84984a")
		field.profile.view_distance = 96.0
		field.profile.density = 1.0
		var provider := TerrainProvider.new()
		provider.terrain = terrain
		field.provider = provider
		field.add_child(provider)
		field.cameras.append(camera)
		add_child(field)

func verify_fixture(data: Object) -> bool:
	var left: float = data.call("get_height", Vector3(-1, 0, 50))
	var right: float = data.call("get_height", Vector3(1, 0, 50))
	var hole: int = data.call("get_control", Vector3(273, 0, 65))
	var painted: int = data.call("get_control", Vector3(0, 0, 22))
	var missing: bool = data.call("has_regionp", Vector3(650, 0, 275))
	var valid := absf(left - ground_height(Vector2(-1, 50))) < 0.02
	valid = valid and absf(right - ground_height(Vector2(1, 50))) < 0.02
	valid = valid and (hole & 4) != 0 and ((painted >> 14) & 255) == 255 and not missing
	if not valid:
		push_error("Terrain fixture failed its seam, hole, paint or missing-region check.")
	return valid

func verify_trail() -> bool:
	var trail := Trail.new()
	trail.update(Vector2.ZERO, [[Vector2(-4, 0), Vector2(4, 0), 0.75, 1.0]], 0.0, 3.5)
	var swept := trail.stamps.has(Vector2i(-7, 0)) and trail.stamps.has(Vector2i(7, 0))
	trail.update(Vector2(1, 0), [], 0.25, 3.5)
	var retained := trail.stamps.has(Vector2i.ZERO)
	trail.update(Vector2(1, 0), [], 4.0, 3.5)
	var recovered := trail.stamps.is_empty()
	trail.update(Vector2.ZERO, [[Vector2.ZERO, Vector2.ZERO, 1.0, 1.0]], 4.1, 3.5)
	trail.update(Vector2(130, 0), [], 4.2, 3.5)
	var cleared := trail.stamps.is_empty()
	if not (swept and retained and recovered and cleared):
		push_error("Grass trail failed sweep, origin shift, recovery or teleport verification.")
		return false
	return true

func install_textures(terrain: Node3D) -> void:
	var assets: Object = terrain.get("assets")
	for id in 2:
		var texture := ClassDB.instantiate("Terrain3DTextureAsset") as Resource
		texture.set("name", "Meadow" if id == 0 else "Bare earth")
		var image := Image.create_empty(64, 64, true, Image.FORMAT_RGBA8)
		var color := Color("606845") if id == 0 else Color("867055")
		for z in 64:
			for x in 64:
				image.set_pixel(x, z, color.darkened(float(hash(Vector2i(x, z)) & 31) / 240.0))
		image.generate_mipmaps()
		texture.set("albedo_texture", ImageTexture.create_from_image(image))
		assets.call("set_texture_asset", id, texture)

func build_region(data: Object, location: Vector2i) -> void:
	var region: Object = data.call("add_region_blank", location, false)
	var heights: Image = region.call("get_map", 0)
	var control := PackedByteArray()
	control.resize(REGION * REGION * 4)
	for z in REGION:
		for x in REGION:
			var world := Vector2(location * REGION + Vector2i(x, z))
			heights.set_pixel(x, z, Color(ground_height(world), 0, 0))
			var path := absf(world.y - 22.0 - sin(world.x * 0.016) * 13.0)
			var blend := roundi(clampf((9.0 - path) / 4.0, 0.0, 1.0) * 255.0)
			var hole := world.distance_to(Vector2(273.0, 65.0)) < 10.0
			control.encode_u32((z * REGION + x) * 4, (1 << 22) | (blend << 14) | (4 if hole else 0))
	region.call("set_map", 1, Image.create_from_data(REGION, REGION, false, Image.FORMAT_RF, control))

func ground_height(point: Vector2) -> float:
	var hills := sin(point.x * 0.022) * 2.5 + sin(point.y * 0.031 + point.x * 0.007) * 2.8
	var bank := 23.0 * smoothstep(91.0, 107.0, point.y)
	return hills + bank

func _process(delta: float) -> void:
	if not camera:
		return
	if not qa_output.is_empty():
		run_visual_probe()
		return
	distance += SPEED * delta
	if distance > FINISH or Input.is_physical_key_pressed(KEY_R):
		distance = START
	move_view()

func move_view() -> void:
	var detour := smoothstep(425.0, 565.0, distance) * (1.0 - smoothstep(685.0, 850.0, distance))
	var ground := Vector2(distance, 42.0 + sin(distance * 0.013) * 24.0 + detour * 253.0)
	vehicle.position = Vector3(ground.x, ground_height(ground), ground.y)
	camera.position = vehicle.position + Vector3(-10.0, 4.0, -4.0)
	var ahead := ground + Vector2(22.0, 1.0)
	camera.look_at(Vector3(ahead.x, ground_height(ahead) + 2.0, ahead.y))

func run_visual_probe() -> void:
	if qa_phase >= 5:
		return
	qa_frames += 1
	distance += SPEED / 60.0
	move_view()
	if qa_frames == 1 and is_instance_valid(field):
		qa_views = field.views[0].slots.size()
	var checkpoints := [-380.0, -5.0, 274.0, 615.0, FINISH]
	var names := ["meadow", "region-seam", "holes-and-path", "missing-region", "revisit"]
	if distance < checkpoints[qa_phase]:
		return
	var name: String = names[qa_phase]
	if qa_phase == 2:
		camera.look_at(Vector3(273, ground_height(Vector2(273, 65)), 65))
	if qa_phase == 4:
		distance = -380.0
		move_view()
	qa_phase += 1
	await RenderingServer.frame_post_draw
	if qa_phase == 1 and is_instance_valid(field):
		qa_first_tiles = visible_tiles()
	var image := get_viewport().get_texture().get_image()
	if image.save_png(qa_output.path_join(name + ".png")) != OK:
		push_error("Could not save demo capture " + name)
		get_tree().quit(1)
	if qa_phase == 5:
		if is_instance_valid(field) and (not field.ready_to_draw or field.views[0].slots.size() != qa_views or visible_tiles() != qa_first_tiles):
			push_error("Grass pool failed to bind, changed size, or assigned different tiles on revisit.")
			get_tree().quit(1)
			return
		print("GRASS_DEMO PASS persistent_slots=", qa_views, " frames=", qa_frames)
		get_tree().quit()

func visible_tiles() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for pair in field.views[0].slots:
		if pair[0].visible or pair[1].visible:
			positions.append(pair[0].position)
	return positions
