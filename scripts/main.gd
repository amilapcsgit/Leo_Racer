extends Node3D

const ROSTER := [
	{"name": "Sonic", "animal": "hedgehog", "tagline": "Blue blur. Big grin. Born for the coast."},
	{"name": "Leo", "animal": "lion", "tagline": "A little lion with a roaring racing heart."},
	{"name": "Ellie", "animal": "elephant", "tagline": "Small kart. Giant island energy."},
	{"name": "Rio", "animal": "parrot", "tagline": "Tropical colour. Fearless corners."}]
const KARTS := [
	{"name": "Blue Bolt", "color": "blue", "speed": 4.5, "grip": 3.9, "accel": 4.1},
	{"name": "Sunset GT", "color": "coral", "speed": 4.8, "grip": 3.6, "accel": 3.8},
	{"name": "Palm Dash", "color": "aqua", "speed": 4.0, "grip": 4.8, "accel": 4.5},
	{"name": "Lotus Pop", "color": "pink", "speed": 4.2, "grip": 4.4, "accel": 4.8}]
var circuit: LeoCircuit
var world: Node3D
var karts: Array[LeoKart] = []
var player: LeoKart
var camera: Camera3D
var hud: LeoHUD
var preview: Node3D
var stage: Node3D
var state := "menu"
var paused := false
var selected_driver := 0
var selected_kart := 0
var countdown := 3.6
var race_time := 0.0
var lap_start := 0.0
var best_lap := 99999.0
var best_time := 0.0
var finish_place := 1
var boost_count := 0
var last_beep := -1
var master_volume := .72
var music_enabled := true
var music: AudioStreamPlayer
var click_sound: AudioStreamPlayer
var countdown_sound: AudioStreamPlayer
var go_sound: AudioStreamPlayer
var finish_sound: AudioStreamPlayer
var environment: Environment
var cam_heading := 0.0
var clock := 0.0
var test_mode := false
var smoke_mode := false
var test_tick := 0
var test_errors: Array[String] = []
var capture_results := false
var wrong_way_time := 0.0
var diagnostics_mode := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	test_mode = "--race-test" in args
	smoke_mode = "--smoke-test" in args
	for arg in args:
		if arg.begins_with("--capture-"): diagnostics_mode = true
	configure_input()
	if not test_mode and not smoke_mode and not diagnostics_mode and "--drive-test" not in args: load_settings()
	circuit = LeoCircuit.new()
	build_world()
	build_stage()
	camera = Camera3D.new()
	camera.fov = 63
	camera.far = 1100
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(camera)
	camera.current = true
	music = make_sound("island_music.wav", -22)
	(music.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	(music.stream as AudioStreamWAV).loop_end = int((music.stream as AudioStreamWAV).get_length() * (music.stream as AudioStreamWAV).mix_rate)
	music.play()
	if not music_enabled: music.stream_paused = true
	click_sound = make_sound("click.wav", -14)
	countdown_sound = make_sound("countdown.wav", -12)
	go_sound = make_sound("go.wav", -12)
	finish_sound = make_sound("finish.wav", -10)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = LeoHUD.new()
	hud.game = self
	layer.add_child(hud)
	return_menu()
	if test_mode or "--show-race" in args:
		start_race()
		if test_mode:
			player.auto_drive = true
			Engine.time_scale = 6
	if "--show-garage" in args: hud.show_garage()
	if "--capture-menu" in args: capture_later("menu")
	if "--capture-race" in args:
		start_race()
		player.auto_drive = true
		capture_later("race", 8.0)
	if "--capture-garage" in args:
		hud.show_garage()
		capture_later("garage", 3.0)
	if "--capture-results" in args:
		capture_results = true
		start_race()
		player.auto_drive = true
		Engine.time_scale = 4
	if "--capture-overview" in args:
		state = "overview"
		hud.menu_root.hide()
		camera.position = Vector3(-225, 155, 250)
		camera.look_at(Vector3(0, 5, -40))
		camera.fov = 55
		capture_later("overview", 2.5)
	if "--capture-v2-tour" in args:
		capture_tour()
	print("LEO_RACER_READY | circuit=%.2fm | assets=Blender GLB | Godot=%s" % [circuit.length, Engine.get_version_info().string])

func configure_input() -> void:
	var bindings := {"accelerate": [KEY_W, KEY_UP], "brake": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "drift": [KEY_SPACE], "boost": [KEY_SHIFT], "recover": [KEY_R], "pause_race": [KEY_ESCAPE, KEY_P], "photo": [KEY_F8]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action, .16)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	for entry in [["left", JOY_AXIS_LEFT_X, -1], ["right", JOY_AXIS_LEFT_X, 1], ["accelerate", JOY_AXIS_TRIGGER_RIGHT, 1], ["brake", JOY_AXIS_TRIGGER_LEFT, 1]]:
		var event := InputEventJoypadMotion.new()
		event.axis = entry[1]
		event.axis_value = entry[2]
		InputMap.action_add_event(entry[0], event)
	for entry in [["drift", JOY_BUTTON_A], ["boost", JOY_BUTTON_X], ["recover", JOY_BUTTON_Y], ["pause_race", JOY_BUTTON_START]]:
		var event := InputEventJoypadButton.new()
		event.button_index = entry[1]
		InputMap.action_add_event(entry[0], event)

func build_world() -> void:
	world = Node3D.new()
	world.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(world)
	var scenery: Node3D = load("res://assets/models/lotus_coast.glb").instantiate()
	world.add_child(scenery)
	polish_materials(scenery)
	var city := LeoCity.new()
	world.add_child(city)
	city.setup(circuit)
	var tower: Node3D = load("res://assets/models/lotus_tower.glb").instantiate()
	tower.position = Vector3(0, .07, -230)
	tower.scale = Vector3.ONE * .85
	world.add_child(tower)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(650,1,650)
	shape.shape = box
	shape.position.y = -.49
	ground.add_child(shape)
	world.add_child(ground)
	var env_node := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := PanoramaSkyMaterial.new()
	sky_material.panorama = load("res://assets/art/lotus_coast_sky.png")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = .42
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = .95
	environment.glow_enabled = true
	environment.glow_intensity = .65
	environment.glow_bloom = .07
	environment.glow_hdr_threshold = 1.4
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.1
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.13
	environment.adjustment_contrast = 1.06
	environment.fog_enabled = true
	environment.fog_light_color = Color("cbdcda")
	environment.fog_density = .0007
	environment.fog_sky_affect = .05
	env_node.environment = environment
	add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28,-145,0)
	sun.light_color = Color("ffe0af")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180
	sun.shadow_bias = .04
	sun.directional_shadow_blend_splits = true
	add_child(sun)
	var ocean := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1100,1500)
	ocean.mesh = plane
	ocean.position = Vector3(-678,-.32,0)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/coastal_water.gdshader")
	ocean.material_override = material
	world.add_child(ocean)
	LeoRaceVisuals.build_boosts(world,circuit)
	LeoRaceVisuals.build_signs(world,circuit)
	if ResourceLoader.exists("res://assets/models/kenney/decoration-tents.glb"):
		for i in range(3):
			var tent: Node3D = load("res://assets/models/kenney/decoration-tents.glb").instantiate()
			tent.position = Vector3(-61+i*8,.03,82)
			tent.scale = Vector3.ONE*3
			world.add_child(tent)
	if ResourceLoader.exists("res://assets/models/city_vehicle.glb"):
		for i in range(4):
			var car: Node3D = load("res://assets/models/city_vehicle.glb").instantiate()
			car.position = Vector3(119,.1,-65+i*10)
			car.rotation.y = PI/2
			world.add_child(car)

func polish_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		for i in instance.mesh.get_surface_count():
			var old := instance.mesh.surface_get_material(i) as StandardMaterial3D
			if old and old.resource_name == "road":
				var material := ShaderMaterial.new()
				material.shader = load("res://shaders/road_surface.gdshader")
				instance.set_surface_override_material(i,material)
	for child in node.get_children(): polish_materials(child)

func build_stage() -> void:
	stage = Node3D.new()
	stage.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	stage.position = Vector3(0, 300, 0)
	add_child(stage)
	var floor_mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 4.6
	cylinder.bottom_radius = 4.7
	cylinder.height = .35
	cylinder.radial_segments = 64
	floor_mesh.mesh = cylinder
	floor_mesh.position.y = -.23
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("102c50")
	mat.metallic = .5
	mat.roughness = .3
	floor_mesh.material_override = mat
	stage.add_child(floor_mesh)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 4.5
	torus.outer_radius = 4.62
	rim.mesh = torus
	mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("43d8ff")
	rim.material_override = mat
	rim.position.y = -.05
	stage.add_child(rim)
	var light := OmniLight3D.new()
	light.position = Vector3(3, 5, -3)
	light.omni_range = 18
	light.light_energy = 2.5
	stage.add_child(light)
	stage.hide()

func update_preview() -> void:
	if is_instance_valid(preview):
		stage.remove_child(preview)
		preview.queue_free()
	preview = Node3D.new()
	stage.add_child(preview)
	preview.add_child(load("res://assets/models/kart_%s.glb" % KARTS[selected_kart].color).instantiate())
	LeoRaceVisuals.polish_chassis(preview.get_child(0))
	preview.add_child(load("res://assets/models/driver_%s.glb" % ROSTER[selected_driver].animal).instantiate())
	preview.rotation.y = -.42

func enter_garage() -> void:
	get_tree().paused = false
	paused = false
	state = "garage"
	remove_racers()
	world.hide()
	stage.show()
	update_preview()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("091c37")
	camera.position = stage.position + Vector3(6.2, 3.8, -8.8)
	camera.look_at(stage.position + Vector3.UP * 1.0)
	camera.look_at(stage.position - camera.global_basis.x * 2.9 + Vector3.UP * 1.0)
	camera.fov = 44

func select_driver(index: int) -> void:
	selected_driver = index
	save_settings()

func select_kart(index: int) -> void:
	selected_kart = index
	save_settings()

func remove_racers() -> void:
	for kart in karts:
		kart.stop_audio()
		remove_child(kart)
		kart.queue_free()
	karts.clear()
	player = null

func return_menu() -> void:
	get_tree().paused = false
	paused = false
	state = "menu"
	remove_racers()
	stage.hide()
	world.show()
	environment.background_mode = Environment.BG_SKY
	camera.position = Vector3(-110, 25, 110)
	camera.look_at(Vector3(0, 15, -25))
	hud.show_menu()

func start_race() -> void:
	get_tree().paused = false
	paused = false
	remove_racers()
	stage.hide()
	world.show()
	environment.background_mode = Environment.BG_SKY
	state = "countdown"
	countdown = 3.6
	race_time = 0
	lap_start = 0
	best_lap = 99999
	boost_count = 0
	wrong_way_time = 0
	last_beep = -1
	for i in range(6):
		var kart := LeoKart.new()
		kart.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(kart)
		var driver_index := selected_driver if i == 0 else i % 4
		var color_index := selected_kart if i == 0 else (i + 1) % 4
		kart.setup(circuit, i, i == 0, ROSTER[driver_index].animal, KARTS[color_index].color)
		LeoRaceVisuals.polish_chassis(kart.chassis)
		kart.racer_name = ROSTER[driver_index].name if i < 4 else ["Kavi", "Nila"][i - 4]
		kart.max_speed = 29.0 + KARTS[color_index].speed * .9 if i == 0 else 29.4 + i * .28
		kart.handling = .8 + KARTS[color_index].grip * .05
		kart.acceleration = 13 + KARTS[color_index].accel * 1.2
		kart.place(-8.0 - (i / 2) * 5.5, -3.2 if i % 2 == 0 else 3.2)
		kart.gate_crossed.connect(on_gate)
		kart.boosted.connect(on_boost)
		karts.append(kart)
	player = karts[0]
	if test_mode: player.auto_drive = true
	cam_heading = player.rotation.y
	camera.fov = 63
	camera.position = player.position + Vector3(sin(cam_heading), 0, cos(cam_heading)) * 9 + Vector3.UP * 5
	camera.look_at(player.position + Vector3.UP * 1.2)
	hud.show_race()

func on_gate(kart: LeoKart, gate: int) -> void:
	if gate > 0 and gate % LeoCircuit.GATES == 0:
		if kart.is_player:
			best_lap = minf(best_lap, race_time - lap_start)
			lap_start = race_time
			if gate < 24:
				hud.announce("FINAL LAP!" if gate == 16 else "LAP 2  /  KEEP IT FLOWING", 2.2)
				go_sound.play()
		if gate == 24 and not kart.finished:
			kart.finished = true
			kart.finish_time = race_time
			kart.active = false
			if kart.is_player:
				finish_place = player_place()
				state = "finishing"
				hud.announce("FINISH!   /   BRING IT HOME", 8.0)
				finish_sound.play()

func on_boost(kart: LeoKart, source: String) -> void:
	if kart.is_player:
		boost_count += 1
		hud.announce(source, 1.1)

func finish_race() -> void:
	if test_mode:
		check(player.lap == 3, "Autonomous racer completes all three laps")
		check(player.next_gate == 25, "Finish requires all 24 ordered sectors after the start gate")
		check(boost_count >= 12, "Boost pads activate across all three laps")
		for kart in karts:
			if not kart.is_player: check(kart.finished, "AI %s completes all three laps without stalling" % kart.racer_name)
	state = "results"
	for kart in karts: kart.active = false
	if best_time <= 0 or player.finish_time < best_time:
		best_time = player.finish_time
		save_settings()
	hud.show_results()
	print("RACE_FINISHED | place=%d | time=%.3f | checkpoints=%d | boosts=%d" % [finish_place, player.finish_time, player.next_gate, boost_count])
	if test_mode: complete_test()
	if capture_results:
		Engine.time_scale = 1
		capture_later("results", 1.0)

func ranking() -> Array:
	var result: Array = karts.duplicate()
	result.sort_custom(func(a: LeoKart, b: LeoKart):
		if a.finished and b.finished: return a.finish_time < b.finish_time
		if a.finished != b.finished: return a.finished
		return a.progress > b.progress)
	return result

func player_place() -> int:
	return ranking().find(player) + 1

func toggle_pause() -> void:
	if state not in ["race", "countdown"]: return
	paused = not paused
	get_tree().paused = paused
	if paused: hud.pause_menu()
	else: hud.clear(hud.modal_root)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_race"):
		if hud.modal_root.get_child_count() > 0 and not paused and state in ["menu", "garage"]: hud.clear(hud.modal_root)
		elif state == "garage": return_menu()
		else: toggle_pause()
	if event.is_action_pressed("recover") and player and state == "race" and not paused:
		player.recover()
		hud.announce("BACK ON TRACK", 1.2)
	if event.is_action_pressed("photo"):
		hud.photo_mode = not hud.photo_mode
		hud.hud_root.visible = not hud.photo_mode

func _process(dt: float) -> void:
	clock += dt
	if state == "garage" and preview:
		preview.rotation.y += dt * .2
	if paused: return
	if state == "countdown":
		countdown -= dt
		var beat := int(ceil(countdown))
		if beat != last_beep and beat <= 3 and beat > 0:
			last_beep = beat
			countdown_sound.play()
		if countdown <= 0:
			state = "race"
			go_sound.play()
			for kart in karts: kart.active = true
	elif state == "race":
		race_time += dt
		var direction := -player.global_basis.z * signf(player.speed)
		if direction.dot(circuit.direction(player.last_s)) < -.25 and absf(player.speed) > 3:
			wrong_way_time += dt
		else: wrong_way_time = 0
	elif state == "finishing":
		race_time += dt
		var all_finished := true
		for kart in karts:
			if not kart.finished: all_finished = false
		if all_finished or race_time - player.finish_time > 25.0: finish_race()
	if state in ["countdown", "race", "finishing"] and player:
		var pose := player.get_global_transform_interpolated()
		cam_heading = lerp_angle(cam_heading, pose.basis.get_euler().y, 1.0-exp(-dt*6.0))
		var behind := Vector3(sin(cam_heading),0,cos(cam_heading))
		camera.position = pose.origin+behind*(7.0+absf(player.speed)*.018)+Vector3.UP*3.4
		camera.look_at(pose.origin-behind*6.0+Vector3.UP*1.85)
		camera.fov = lerpf(camera.fov, 74.0 if player.boost_time > 0 else 63.0 + absf(player.speed) * .1, minf(1, dt * 4))
		for kart in karts:
			if not kart.is_player:
				kart.visual.visible = (kart.position - player.position).dot(-player.global_basis.z) > -3.0 or kart.position.distance_to(camera.position) > 7.0
	if smoke_mode:
		test_tick += 1
		if test_tick == 30: run_smoke_checks()
	if test_mode and state == "race" and race_time > 180:
		test_errors.append("Autonomous player failed to complete in 180 simulated seconds")
		complete_test()

func make_sound(file: String, volume: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load("res://assets/audio/" + file)
	p.volume_db = volume
	add_child(p)
	return p

func ui_click() -> void:
	click_sound.play()

func set_volume(value: float) -> void:
	master_volume = value
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, .0001)))
	save_settings()

func set_music(enabled: bool) -> void:
	music_enabled = enabled
	music.stream_paused = not enabled
	save_settings()

func set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	save_settings()

func save_settings() -> void:
	if test_mode or smoke_mode or diagnostics_mode or "--drive-test" in OS.get_cmdline_user_args(): return
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", master_volume)
	cfg.set_value("audio", "music", music_enabled)
	cfg.set_value("game", "driver", selected_driver)
	cfg.set_value("game", "kart", selected_kart)
	cfg.set_value("game", "best_time", best_time)
	cfg.set_value("display", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	cfg.save("user://leo_racer.cfg")

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://leo_racer.cfg") == OK:
		master_volume = cfg.get_value("audio", "volume", .72)
		music_enabled = cfg.get_value("audio", "music", true)
		selected_driver = clampi(cfg.get_value("game", "driver", 0), 0, 3)
		selected_kart = clampi(cfg.get_value("game", "kart", 0), 0, 3)
		best_time = cfg.get_value("game", "best_time", 0.0)
		if cfg.get_value("display", "fullscreen", false): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, .0001)))

func format_time(seconds: float) -> String:
	if seconds > 9999: return "--:--.---"
	return "%02d:%02d.%03d" % [int(seconds) / 60, int(seconds) % 60, int(fmod(seconds, 1) * 1000)]

func quit_game() -> void:
	stop_all_audio()
	get_tree().quit()

func stop_all_audio() -> void:
	music.stop()
	click_sound.stop()
	countdown_sound.stop()
	go_sound.stop()
	finish_sound.stop()
	for kart in karts: kart.stop_audio()

func capture_later(label: String, wait: float = 2.0) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var saved := image.save_png(diagnostic_path(label + ".png"))
	if saved != OK: push_error("Could not save verification screenshot: %s" % saved)
	print("SCREENSHOT_SAVED ", label)
	if not test_mode: quit_game()

func capture_tour() -> void:
	start_race()
	state = "tour"
	hud.photo_mode = true
	hud.hud_root.hide()
	var locations := [30.0, circuit.length*.36, circuit.length*.57, circuit.length*.82]
	var names := ["coast", "fort", "lotus", "gardens"]
	for i in locations.size():
		player.place(locations[i],-1)
		var t := circuit.direction(locations[i])
		camera.position = player.position-t*7.4+Vector3.UP*3.4
		camera.look_at(player.position+t*6+Vector3.UP*1.85)
		camera.fov = 64
		await get_tree().create_timer(.8).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(diagnostic_path("qa-v2/"+names[i]+".png"))
	# Reverse-side start gate is an intentional independent face, never mirrored.
	camera.position = Vector3(-90,5.5,47)
	camera.look_at(Vector3(-90,6,72))
	await get_tree().create_timer(.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(diagnostic_path("qa-v2/sign-back.png"))
	# View the directional chevrons before reaching them.
	var s := float(circuit.boosts[0])*circuit.length-13
	player.place(s,0)
	var t := circuit.direction(s)
	camera.position = player.position-t*7.4+Vector3.UP*3.4
	camera.look_at(player.position+t*6+Vector3.UP*1.85)
	await get_tree().create_timer(.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(diagnostic_path("qa-v2/boost-forward.png"))
	print("V2_TOUR_CAPTURED")
	quit_game()

func diagnostic_path(file: String) -> String:
	return "res://docs/" + file if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join(file)

func check(condition: bool, message: String) -> void:
	if not condition: test_errors.append(message)
	print(("PASS " if condition else "FAIL ") + message)

func run_smoke_checks() -> void:
	check(circuit.length > 700, "Circuit loads with expected length")
	check(circuit.sample(0).distance_to(circuit.sample(circuit.length)) < .001, "Track closes without a seam")
	check(absf(circuit.delta_distance(circuit.length - 2, 2) - 4) < .001, "Finish seam uses signed forward distance")
	for fraction in [.0, .17, .43, .8, .99]:
		var s: float = circuit.length * fraction
		var projection := circuit.project(circuit.sample(s, 4))
		check(absf(projection.offset - 4) < .15, "Projection and lane offset agree at %.2f" % fraction)
	start_race()
	check(karts.size() == 6 and player.is_player, "Six racers spawn with one local player")
	check(player.wheels.size() == 4, "Four animated wheel pivots are imported")
	check(player.get_child_count() >= 4, "Visuals collision and audio are attached")
	player.next_gate = 7
	player.progress = circuit.length * .9
	player.recover()
	check(player.next_gate == 7 and player.progress < circuit.length, "Recovery cannot award or skip checkpoints")
	player.boost_fuel = 1
	player.boost(1.5, "TEST")
	check(player.boost_time >= 1.5, "Boost activates and reports to HUD")
	toggle_pause()
	check(paused and get_tree().paused, "Pause freezes race physics")
	hud.show_settings()
	hud.close_settings()
	for control in hud.modal_root.get_children():
		if control is Button and control.text == "RESUME RACE": control.pressed.emit(); break
	check(not paused and not get_tree().paused, "Settings returns to pause menu and Resume restores race physics")
	start_race()
	check(player.next_gate == 0 and player.lap == 1 and boost_count == 0, "Restart clears checkpoint lap and boost state")
	hud.show_garage()
	check(state == "garage" and stage.visible, "Garage shows modular preview")
	for i in range(4):
		selected_driver = i
		selected_kart = 3 - i
		update_preview()
	check(preview.get_child_count() == 2, "Every driver and kart combination loads independently")
	selected_driver = 0
	selected_kart = 0
	return_menu()
	check(state == "menu" and karts.is_empty(), "Return to menu frees race instances")
	complete_test()

func complete_test() -> void:
	Engine.time_scale = 1
	var report := {"status": "PASS" if test_errors.is_empty() else "FAIL", "errors": test_errors, "race_time": player.finish_time if player else race_time, "boosts": boost_count, "engine": Engine.get_version_info().string}
	var file := FileAccess.open(diagnostic_path("race-test.json" if test_mode else "smoke-test.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("LEO_TEST_REPORT ", JSON.stringify(report))
	stop_all_audio()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if test_errors.is_empty() else 1)
