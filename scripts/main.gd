extends Node3D

var input_router: LeoInputRouter
var catalog: GarageCatalog
var ROSTER: Array = []
var KARTS: Array = []
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
var custom_player_name := ""
var garage_from_pause := false
var race_modified := false
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
var art_profile: LeoArtProfile = preload("res://assets/config/astra.tres")
var feedback: Node
var reduced_motion := false
var camera_roll := 0.0
var launch_charged := false
var horn_cooldown := 0.0
var slipstream_time := 0.0
var slipstream_cooldown := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	catalog = GarageCatalog.shared()
	var args := OS.get_cmdline_user_args()
	test_mode = "--race-test" in args
	smoke_mode = "--smoke-test" in args
	for arg in args:
		if arg.begins_with("--capture-"): diagnostics_mode = true
	for d in catalog.drivers: ROSTER.append({"name":d.display_name,"animal":String(d.id),"tagline":d.tagline})
	for v in catalog.vehicles: KARTS.append({"name":v.display_name,"color":String(v.id),"speed":(v.max_speed-29.)/.9,"grip":(v.handling-.8)/.05,"accel":(v.acceleration-13.)/1.2,"top":v.max_speed})
	configure_input()
	input_router = LeoInputRouter.new()
	input_router.name = "PlayerInputs"
	add_child(input_router)
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
	feedback = load("res://scripts/RaceFeedbackBridge.cs").new()
	feedback.name = "RaceFeedback"
	add_child(feedback)
	feedback.configure(art_profile.camera_boost_peak,art_profile.camera_boost_hold)
	feedback.set_reduced_motion(reduced_motion)
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
	var bindings := {"accelerate": [KEY_W, KEY_UP], "brake": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "drift": [KEY_SPACE], "boost": [KEY_SHIFT], "recover": [KEY_R], "pause_race": [KEY_ESCAPE, KEY_P], "photo": [KEY_F8], "horn": [KEY_H]}
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
	for entry in [["drift", JOY_BUTTON_A], ["boost", JOY_BUTTON_X], ["recover", JOY_BUTTON_Y], ["horn", JOY_BUTTON_B], ["pause_race", JOY_BUTTON_START]]:
		var event := InputEventJoypadButton.new()
		event.button_index = entry[1]
		InputMap.action_add_event(entry[0], event)

func build_world() -> void:
	world = Node3D.new()
	world.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(world)
	if not art_profile.world_model.is_empty():
		var scenery: Node3D = load(art_profile.world_model).instantiate()
		world.add_child(scenery)
		polish_materials(scenery)
	var city := LeoCity.new()
	world.add_child(city)
	city.setup(circuit,art_profile)
	var colombo := LeoAstraWorld.new()
	world.add_child(colombo)
	colombo.setup(circuit,art_profile)
	var tower: Node3D = load(art_profile.landmark_model).instantiate()
	tower.position = art_profile.landmark_position
	tower.scale = Vector3.ONE * art_profile.landmark_scale
	tower.name = "AuthenticLotusTower"
	world.add_child(tower)
	polish_materials(tower,true)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1000,1,1000)
	shape.shape = box
	shape.position = Vector3(75,-.49,-50)
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
	LeoColomboWorld.environment_setup(environment,sun,art_profile)
	LeoRaceVisuals.build_boosts(world,circuit)
	LeoRaceVisuals.build_signs(world,circuit)
	LeoAstraDecals.build(world,circuit)
	if ResourceLoader.exists("res://assets/models/kenney/decoration-tents.glb"):
		for i in range(3):
			var tent: Node3D = load("res://assets/models/kenney/decoration-tents.glb").instantiate()
			tent.position = Vector3(-61+i*8,.03,82)
			tent.scale = Vector3.ONE*3
			world.add_child(tent)

func polish_materials(node: Node, landmark: bool=false) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		for i in instance.mesh.get_surface_count():
			var old := instance.mesh.surface_get_material(i) as StandardMaterial3D
			if old and old.resource_name == "road":
				var material := ShaderMaterial.new()
				material.shader = load("res://shaders/road_surface.gdshader")
				material.set_shader_parameter("base_roughness",art_profile.road_roughness)
				for pair in [["color_map","Color"],["normal_map","NormalGL"],["rough_map","Roughness"]]:
					material.set_shader_parameter(pair[0],load("res://assets/materials/Asphalt023S_2K-JPG_%s.jpg"%pair[1]))
				instance.set_surface_override_material(i,material)
			elif old and old.resource_name in ["white","navy"] and not landmark:
				var paint:=ShaderMaterial.new()
				paint.shader=load("res://shaders/road_marking.gdshader")
				paint.set_shader_parameter("paint",Color("d9d6c8") if old.resource_name=="white" else Color("14212b"))
				instance.set_surface_override_material(i,paint)
			elif old:
				var material := old.duplicate() as StandardMaterial3D
				var colors := {"grass":"254e38","grasslight":"3b6533","cyan":"779a9d","cream":"cabb9d","white":"d9d8cb","leaf":"1b6337","leaflight":"417e2d","sand":"c3a26a","pink":"a32868","purple":"693774"}
				if colors.has(old.resource_name): material.albedo_color = Color(colors[old.resource_name])
				if old.resource_name in ["pink","purple","gold"]:
					material.metallic = .5
					material.roughness = .3
				if landmark and old.resource_name in ["pink","purple"]:
					material.emission_enabled = true
					material.emission = Color("cf3d9d") if old.resource_name=="pink" else Color("6c279c")
					material.emission_energy_multiplier = .55
				instance.set_surface_override_material(i,material)
	for child in node.get_children(): polish_materials(child,landmark)

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
	light.light_color = Color("ffdfb5")
	stage.add_child(light)
	var edge_light := OmniLight3D.new()
	edge_light.position = Vector3(-4,3,3)
	edge_light.omni_range = 14
	edge_light.light_color = Color("13c8ed")
	edge_light.light_energy = 2.0
	stage.add_child(edge_light)
	stage.hide()

func update_preview() -> void:
	if hud and is_instance_valid(hud.garage_selector):
		hud.garage_selector.set_selection(ROSTER[selected_driver].animal,KARTS[selected_kart].color)
		preview = hud.garage_selector.assembly

func enter_garage(retain_race: bool=false) -> void:
	garage_from_pause=retain_race
	if retain_race:
		paused=true
		get_tree().paused=true
		return
	get_tree().paused = false
	paused = false
	state = "garage"
	remove_racers()
	world.hide()
	stage.hide()

func showroom_lighting(enabled: bool) -> void:
	environment.fog_enabled = not enabled
	environment.volumetric_fog_enabled = not enabled and RenderingServer.get_current_rendering_method()=="forward_plus"
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR if enabled else Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color("558fa2")
	environment.ambient_light_energy = .55 if enabled else art_profile.ambient_energy
	environment.tonemap_exposure = .9 if enabled else art_profile.exposure

func select_driver(index: int) -> void:
	selected_driver = index
	save_settings()

func select_kart(index: int) -> void:
	selected_kart = index
	save_settings()

func remove_racers() -> void:
	if feedback: feedback.reset_feedback()
	camera_roll = 0.0
	for kart in karts:
		kart.stop_audio()
		remove_child(kart)
		kart.queue_free()
	karts.clear()
	player = null

func return_menu() -> void:
	garage_from_pause=false
	showroom_lighting(false)
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
	garage_from_pause=false
	race_modified=false
	showroom_lighting(false)
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
	launch_charged = false
	horn_cooldown = 0
	slipstream_time = 0
	slipstream_cooldown = 0
	last_beep = -1
	for i in range(6):
		var kart := LeoKart.new()
		kart.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(kart)
		var driver_index := selected_driver if i == 0 else i % ROSTER.size()
		var color_index: int = selected_kart if i == 0 else (selected_kart+i*3) % catalog.vehicles.size()
		kart.setup(circuit, i, i == 0, ROSTER[driver_index].animal, KARTS[color_index].color)
		kart.racer_name = ROSTER[driver_index].name
		if i==0 and not custom_player_name.strip_edges().is_empty():kart.racer_name=custom_player_name.strip_edges()
		kart.max_speed *= 1.0 if i==0 else .96
		kart.place(-8.0 - (i / 2) * 5.5, -3.2 if i % 2 == 0 else 3.2)
		kart.gate_crossed.connect(on_gate)
		kart.boosted.connect(on_boost)
		kart.impacted.connect(on_impact)
		kart.recovered.connect(on_recover)
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
				hud.play_arcade_cue("lap")
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
		feedback.play_boost(source,kart.boost_time)
		boost_count += 1
		hud.announce(source, 1.1)

func on_impact(kart: LeoKart, _point: Vector3, _normal: Vector3, strength: float) -> void:
	if kart.is_player: feedback.play_impact(strength)

func on_recover(kart: LeoKart) -> void:
	if kart.is_player:
		feedback.play_recover()
		cam_heading = kart.rotation.y
		camera_roll = 0.0
		slipstream_time = 0.0
		hud.announce("BACK ON TRACK",1.2)

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if feedback: feedback.set_reduced_motion(value)
	save_settings()

func finish_race() -> void:
	if test_mode:
		check(player.lap == 3, "Autonomous racer completes all three laps")
		check(player.next_gate == 25, "Finish requires all 24 ordered sectors after the start gate")
		check(boost_count >= 12, "Boost pads activate across all three laps")
		for kart in karts:
			if not kart.is_player: check(kart.finished, "AI %s completes all three laps without stalling" % kart.racer_name)
	state = "results"
	feedback.reset_feedback()
	for kart in karts: kart.active = false
	if not race_modified and (best_time <= 0 or player.finish_time < best_time):
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

func apply_garage_selection(d: StringName,v: StringName,player_name: String) -> void:
	selected_driver=catalog.driver_index(d)
	selected_kart=catalog.vehicle_index(v)
	custom_player_name=player_name.strip_edges().left(32)
	save_settings()

func cancel_pause_garage() -> void:
	garage_from_pause=false
	if is_instance_valid(hud.garage_selector):hud.garage_selector.hide()
	hud.menu_root.hide()
	hud.hud_root.show()
	hud.scene_mode="race"
	hud.pause_menu()

func swap_player_vehicle(d: StringName,v: StringName,player_name: String) -> bool:
	if not garage_from_pause or not paused or not is_instance_valid(player):return false
	var old:=player
	var fresh:=LeoKart.new()
	fresh.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(fresh)
	fresh.setup(circuit,old.racer_id,true,String(d),String(v))
	var query:=PhysicsShapeQueryParameters3D.new()
	var shape:=BoxShape3D.new();shape.size=fresh.definition.collision_size
	query.shape=shape;query.collision_mask=3;query.exclude=[old.get_rid(),fresh.get_rid()]
	var tangent:=circuit.direction(old.last_s)
	var heading:=atan2(-tangent.x,-tangent.z)
	var basis:=Basis(Vector3.UP,heading)
	var lane: float=circuit.project(old.position).offset
	var safe_position:=Vector3.ZERO
	var found:=false
	# Try the existing lane first, then nearby lanes at EXACTLY the same
	# circuit distance. No forward teleport can skip a checkpoint.
	var half_road: float=LeoCircuit.WIDTH*.5-fresh.definition.collision_size.x*.5-.45
	lane=clampf(lane,-half_road,half_road)
	var candidates: Array[float]=[lane]
	for i in range(1,ceili(2*half_road/.30)+1):
		var offset:=i*.30
		for side in [-1.,1.]:
			var candidate: float=lane+offset*float(side)
			if absf(candidate)<=half_road:candidates.append(candidate)
	for candidate in candidates:
		var position_at:=circuit.sample(old.last_s,candidate)+Vector3.UP*.12
		query.transform=Transform3D(basis,position_at+basis*fresh.definition.collision_position)
		if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
			safe_position=position_at;found=true;break
	if not found:
		fresh.stop_audio();fresh.queue_free()
		hud.garage_selector.policy.text="TRACK BUSY — BACK TO PAUSE, RESUME, THEN TRY AGAIN"
		return false
	fresh.position=safe_position;fresh.rotation.y=heading
	for property in ["progress","next_gate","lap","last_s","nearest_index","finished","finish_time","active","auto_drive"]:fresh.set(property,old.get(property))
	fresh.speed=clampf(old.speed,-10.,fresh.max_speed)
	fresh.velocity=-fresh.global_basis.z*fresh.speed
	fresh.boost_fuel=old.boost_fuel
	fresh.racer_name=player_name.strip_edges() if not player_name.strip_edges().is_empty() else catalog.driver(d).display_name
	fresh.gate_crossed.connect(on_gate);fresh.boosted.connect(on_boost);fresh.impacted.connect(on_impact);fresh.recovered.connect(on_recover)
	fresh.reset_physics_interpolation()
	old.effects._recover(old);old.stop_audio();remove_child(old);old.queue_free()
	karts[0]=fresh;player=fresh
	race_modified=true;garage_from_pause=false
	feedback.reset_feedback();camera_roll=0.;slipstream_time=0.;cam_heading=heading
	apply_garage_selection(d,v,player_name)
	paused=false;get_tree().paused=false
	hud.show_race();hud.announce("CAR CHANGED  //  MODIFIED RACE — NO RECORD",3.0)
	return true

func toggle_pause() -> void:
	if state not in ["race", "countdown"]: return
	paused = not paused
	get_tree().paused = paused
	if paused: hud.pause_menu()
	else: hud.clear(hud.modal_root)

func _unhandled_input(event: InputEvent) -> void:
	if garage_from_pause:
		if event.is_action_pressed("pause_race"):cancel_pause_garage()
		return
	if event.is_action_pressed("accelerate") and state=="countdown" and countdown>0 and countdown<=1.05 and not paused:
		launch_charged = true
	if event.is_action_pressed("horn") and player and state=="race" and not paused and horn_cooldown<=0:
		horn_cooldown = .8
		hud.play_arcade_cue("bus_horn" if player.vehicle_key=="race_bus" else "tuk_horn")
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
	if state == "garage":
		pass
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
			if launch_charged: player.boost(.9,"PERFECT LAUNCH")
	elif state == "race":
		race_time += dt
		horn_cooldown = maxf(0,horn_cooldown-dt)
		update_slipstream(dt)
		var direction := -player.global_basis.z * signf(player.speed)
		if direction.dot(circuit.direction(player.last_s)) < -.25 and absf(player.speed) > 3:
			wrong_way_time += dt
		else: wrong_way_time = 0
	elif state == "finishing":
		race_time += dt
		var all_finished := true
		for kart in karts:
			if not kart.finished: all_finished = false
		if all_finished or race_time-player.finish_time > (70.0 if test_mode or diagnostics_mode else 4.0): finish_race()
	if state in ["countdown", "race", "finishing"] and player:
		var pose := player.get_global_transform_interpolated()
		cam_heading = lerp_angle(cam_heading, pose.basis.get_euler().y, 1.0-exp(-dt*6.0))
		var behind := Vector3(sin(cam_heading),0,cos(cam_heading))
		camera.position = pose.origin+behind*(6.4+absf(player.speed)*.012)+Vector3.UP*(3.1+player.camera_height_offset)
		camera.look_at(pose.origin-behind*6.0+Vector3.UP*(1.85+player.camera_height_offset*.5))
		feedback.set_boost_active(player.boost_time>0 and player.active)
		var base_fov := 63.0+absf(player.speed)*.1
		camera.fov = lerpf(camera.fov,base_fov+float(feedback.get_fov_offset()),1.0-exp(-dt*12.0))
		var roll_target := 0.0 if reduced_motion else -player.steer*deg_to_rad(art_profile.camera_roll_degrees)*clampf(absf(player.speed)/36.0,0,1)
		camera_roll = lerpf(camera_roll,roll_target,1.0-exp(-dt*6.0))
		camera.rotate_object_local(Vector3.FORWARD,camera_roll+float(feedback.get_shake_roll()))
		camera.position += camera.global_basis*Vector3(feedback.get_shake_offset())
		for kart in karts:
			if not kart.is_player:
				kart.visual.visible = (kart.position - player.position).dot(-player.global_basis.z) > -3.0 or kart.position.distance_to(camera.position) > 7.0
	if smoke_mode:
		test_tick += 1
		if test_tick == 30: run_smoke_checks()
	if test_mode and state in ["race","finishing"] and race_time > circuit.length*3/15.0:
		test_errors.append("Autonomous race exceeded route-scaled time limit")
		complete_test()

func update_slipstream(dt: float) -> void:
	slipstream_cooldown = maxf(0,slipstream_cooldown-dt)
	var drafting := false
	if player.active and absf(player.wheel_motion_speed)>16:
		var forward := -player.global_basis.z
		for other in karts:
			if other==player or not other.active: continue
			var gap := other.position-player.position
			var ahead := gap.dot(forward)
			var lateral := absf(gap.dot(player.global_basis.x))
			if ahead>5 and ahead<19 and lateral<2.4 and forward.dot(-other.global_basis.z)>.85:
				drafting = true
				break
	if drafting:
		slipstream_time += dt
		player.boost_fuel = minf(1,player.boost_fuel+dt*.13)
		if slipstream_time>.8 and slipstream_cooldown<=0:
			hud.announce("SLIPSTREAM  //  NITRO CHARGING",1.4)
			slipstream_cooldown = 5.0
	else: slipstream_time = 0.0

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
	cfg.load("user://leo_racer.cfg")
	cfg.set_value("audio", "volume", master_volume)
	cfg.set_value("audio", "music", music_enabled)
	cfg.set_value("game", "driver", selected_driver)
	cfg.set_value("game", "kart", selected_kart)
	cfg.set_value("game","driver_id",String(catalog.drivers[selected_driver].id))
	cfg.set_value("game","vehicle_id",String(catalog.vehicles[selected_kart].id))
	cfg.set_value("game","custom_player_name",custom_player_name.strip_edges())
	cfg.set_value("game", "best_time_astra", best_time)
	cfg.set_value("display", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	cfg.set_value("display", "reduced_motion", reduced_motion)
	cfg.save("user://leo_racer.cfg")

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://leo_racer.cfg") == OK:
		master_volume = cfg.get_value("audio", "volume", .72)
		music_enabled = cfg.get_value("audio", "music", true)
		reduced_motion = cfg.get_value("display", "reduced_motion", false)
		var selection := catalog.migrate(cfg)
		selected_driver = selection.x
		selected_kart = selection.y
		custom_player_name=str(cfg.get_value("game","custom_player_name","")).left(32)
		best_time = cfg.get_value("game", "best_time_astra", 0.0)
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
	return "res://docs/qa-modular-garage/" + file if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join(file)

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
	set_reduced_motion(true)
	player.boost(1.5,"TEST REDUCED MOTION")
	check(feedback.get_fov_offset()==0 and feedback.get_shake_offset()==Vector3.ZERO,"Reduced Motion suppresses camera effects in the packaged game")
	set_reduced_motion(false)
	check(LeoHUD.speed_line_strength(149.0/3.6,false,true,false)==0 and LeoHUD.speed_line_strength(180.0/3.6,false,true,false)>.6,"Measured speed lines use the 150 to 180 km/h threshold")
	hud.play_arcade_cue("tuk_horn")
	hud.play_arcade_cue("bus_horn")
	var retained_gate:=player.next_gate
	var retained_time:=race_time
	var retained_opponent:=karts[1]
	toggle_pause()
	hud.show_garage("pause")
	check(paused and get_tree().paused and garage_from_pause,"Packaged pause garage retains the frozen race")
	check(swap_player_vehicle(&"mario",&"duster","PACKAGED PILOT"),"Packaged Continue swaps only the player")
	check(player.next_gate==retained_gate and race_time==retained_time and karts[1]==retained_opponent and race_modified,"Packaged swap preserves race state and excludes records")
	check(player.driver.get_meta("visible_driver_id")==&"human" and player.visual.get_meta("driver_id")==&"mario","Packaged Dacia shows helmet driver with independent identity")
	start_race()
	check(player.next_gate == 0 and player.lap == 1 and boost_count == 0, "Restart clears checkpoint lap and boost state")
	hud.show_garage()
	check(state == "garage" and is_instance_valid(hud.garage_selector), "Garage shows modular preview")
	for i in ROSTER.size():
		selected_driver = i
		for j in KARTS.size():
			selected_kart = j
			update_preview()
	check(is_instance_valid(preview), "Every driver and kart combination loads independently")
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
