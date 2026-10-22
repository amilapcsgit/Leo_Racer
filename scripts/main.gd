extends Node3D

var split_view: LeoSplitRaceView
var input_router: LeoInputRouter
var local_players: Array[LeoLocalPlayer] = [LeoLocalPlayer.new(0),LeoLocalPlayer.new(1)]
var human_count := 1
var selected_player_slot := 0
var disconnect_message := ""
var session_id := ""
var ranking_store: RefCounted
var rankings_written := false
var ranking_message := ""
var legacy_best_time := 0.0
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
	for v in catalog.vehicles:
		var rules:=LeoRaceRules.resolve(v)
		KARTS.append({"name":v.display_name,"color":String(v.id),"speed":(rules.max_speed-29.)/.9,"grip":(rules.handling-.8)/.05,"accel":(rules.acceleration-13.)/1.2,"top":rules.max_speed})
	configure_input()
	input_router = LeoInputRouter.new()
	input_router.name = "PlayerInputs"
	add_child(input_router)
	input_router.command.connect(_on_local_command)
	input_router.device_lost.connect(_on_device_lost)
	if not diagnostic_run():
		load_settings()
		open_rankings()
		save_settings()
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
	split_view=LeoSplitRaceView.new();split_view.game=self;layer.add_child(split_view);layer.move_child(split_view,0)
	var second_feedback=load("res://scripts/RaceFeedbackBridge.cs").new()
	second_feedback.name="Player2Feedback";second_feedback.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(second_feedback)
	second_feedback.configure(art_profile.camera_boost_peak,art_profile.camera_boost_hold);second_feedback.set_reduced_motion(reduced_motion)
	local_players[1].feedback=second_feedback
	feedback.process_mode=Node.PROCESS_MODE_PAUSABLE
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
	if split_view:split_view.activate(false)
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
	session_id=Crypto.new().generate_random_bytes(16).hex_encode()
	rankings_written=false;ranking_message=""
	showroom_lighting(false)
	get_tree().paused=false;paused=false
	remove_racers()
	stage.hide();world.show()
	environment.background_mode=Environment.BG_SKY
	state="countdown";countdown=3.6;race_time=0;lap_start=0;best_lap=99999;boost_count=0
	wrong_way_time=0;launch_charged=false;horn_cooldown=0;slipstream_time=0;slipstream_cooldown=0;last_beep=-1
	local_players[0].driver_id=catalog.drivers[selected_driver].id
	local_players[0].vehicle_id=catalog.vehicles[selected_kart].id
	local_players[0].player_name=custom_player_name
	input_router.active_slots=human_count;input_router.clear_all()
	for local in local_players:local.reset_race()
	var row_span:=0.
	for vehicle in catalog.vehicles:row_span=maxf(row_span,vehicle.collision_size.z+1.2)
	for i in 6:
		var kart:=LeoKart.new();kart.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(kart)
		var d: StringName=local_players[i].driver_id if i<human_count else catalog.drivers[i%catalog.drivers.size()].id
		var v: StringName=local_players[i].vehicle_id if i<human_count else catalog.vehicles[(selected_kart+i*3)%catalog.vehicles.size()].id
		kart.setup(circuit,i,i<human_count,String(d),String(v))
		LeoRaceRules.apply(kart)
		kart.racer_name=catalog.driver(d).display_name
		if i<human_count:
			var local:=local_players[i]
			local.kart=kart;kart.local_slot=i;kart.control_input=input_router.players[i]
			if not local.player_name.strip_edges().is_empty():kart.racer_name=local.player_name.strip_edges()
			local.heading=kart.rotation.y
			if kart.engine and human_count==2:kart.engine.volume_db-=3.
		kart.place(-8.-(i/2)*row_span,-3.2 if i%2==0 else 3.2)
		kart.gate_crossed.connect(on_gate);kart.boosted.connect(on_boost);kart.impacted.connect(on_impact);kart.recovered.connect(on_recover)
		karts.append(kart)
	player=karts[0]
	local_players[0].camera=camera;local_players[0].feedback=feedback
	if test_mode:player.auto_drive=true
	cam_heading=player.rotation.y;camera.fov=63
	camera.position=player.position+Vector3(sin(cam_heading),0,cos(cam_heading))*9+Vector3.UP*5
	camera.look_at(player.position+Vector3.UP*1.2)
	if split_view:split_view.activate(human_count==2)
	hud.show_race()

func on_gate(kart: LeoKart, gate: int) -> void:
	var local:=state_for(kart)
	if gate>0 and gate%LeoCircuit.GATES==0 and local:
		local.best_lap=minf(local.best_lap,race_time-local.lap_started)
		local.lap_started=race_time
		if gate<24:
			announce_player(local.slot,"FINAL LAP!" if gate==16 else "LAP 2 / KEEP IT FLOWING",2.2)
			hud.play_arcade_cue("lap")
		if local.slot==0:best_lap=local.best_lap;lap_start=local.lap_started
	if gate==24 and not kart.finished and not kart.retired:
		kart.finished=true;kart.finish_time=race_time;kart.active=false;kart.boost_time=0
		kart.collision_layer=0;kart.collision_mask=1
		if local:
			announce_player(local.slot,"FINISHED / WAITING FOR OTHER RACERS",8.)
			finish_sound.play()
			if local.slot==0:finish_place=ranking().find(kart)+1
			if human_count==1:state="finishing"

func on_boost(kart: LeoKart, source: String) -> void:
	var local:=state_for(kart)
	if local:
		local.boost_count+=1
		if local.feedback:local.feedback.play_boost(source,kart.boost_time)
		if local.slot==0:boost_count=local.boost_count
		announce_player(local.slot,source,1.1)

func on_impact(kart: LeoKart, _point: Vector3, _normal: Vector3, strength: float) -> void:
	var local:=state_for(kart)
	if local and local.feedback:local.feedback.play_impact(strength)

func on_recover(kart: LeoKart) -> void:
	var local:=state_for(kart)
	if local:
		if local.feedback:local.feedback.play_recover()
		local.heading=kart.rotation.y;local.roll=0.;local.slipstream_time=0.
		if local.slot==0:cam_heading=kart.rotation.y;camera_roll=0.;slipstream_time=0.
		announce_player(local.slot,"BACK ON TRACK",1.2)

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if feedback: feedback.set_reduced_motion(value)
	if local_players[1].feedback:local_players[1].feedback.set_reduced_motion(value)
	save_settings()

func finish_race() -> void:
	if test_mode:
		check(player.lap == 3, "Autonomous racer completes all three laps")
		check(player.next_gate == 25, "Finish requires all 24 ordered sectors after the start gate")
		check(boost_count >= 12, "Boost pads activate across all three laps")
		for kart in karts:
			if not kart.is_player: check(kart.finished, "AI %s completes all three laps without stalling" % kart.racer_name)
	state = "results"
	if split_view:split_view.set_frozen(true)
	for local in local_players:
		if local.feedback:local.feedback.reset_feedback()
	for kart in karts: kart.active = false
	save_ranking_results()
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
		if a.retired != b.retired:return not a.retired
		return a.progress > b.progress)
	return result

func player_place(slot: int = 0) -> int:
	return ranking().find(local_players[slot].kart if local_players[slot].kart else player)+1

func apply_garage_selection(d: StringName,v: StringName,player_name: String) -> void:
	var local:=local_players[selected_player_slot]
	local.driver_id=d;local.vehicle_id=v;local.player_name=player_name.strip_edges().left(32)
	if selected_player_slot==0:
		selected_driver=catalog.driver_index(d);selected_kart=catalog.vehicle_index(v);custom_player_name=local.player_name
	save_settings()

func cancel_pause_garage() -> void:
	garage_from_pause=false
	if is_instance_valid(hud.garage_selector):hud.garage_selector.hide()
	hud.menu_root.hide()
	hud.hud_root.show()
	hud.scene_mode="race"
	hud.pause_menu()

func swap_player_vehicle(d: StringName,v: StringName,player_name: String) -> bool:
	if not garage_from_pause or not paused or not is_instance_valid(local_players[selected_player_slot].kart):return false
	var local:=local_players[selected_player_slot]
	var old:=local.kart
	if old.finished or old.retired:return false
	var fresh:=LeoKart.new()
	fresh.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(fresh)
	fresh.setup(circuit,old.racer_id,true,String(d),String(v))
	LeoRaceRules.apply(fresh)
	fresh.local_slot=selected_player_slot;fresh.control_input=input_router.players[selected_player_slot]
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
	karts[karts.find(old)]=fresh;local.kart=fresh
	if selected_player_slot==0:player=fresh
	race_modified=true;garage_from_pause=false
	if local.feedback:local.feedback.reset_feedback()
	local.roll=0.;local.slipstream_time=0.;local.heading=heading
	camera_roll=0.;slipstream_time=0.;cam_heading=heading
	apply_garage_selection(d,v,player_name)
	paused=false;get_tree().paused=false
	input_router.clear_all()
	if split_view:split_view.set_frozen(false)
	hud.show_race();hud.announce("CAR CHANGED  //  MODIFIED RACE — NO RECORD",3.0)
	return true

func toggle_pause() -> void:
	if state not in ["race","countdown","finishing"]:return
	if paused and not diagnostics_mode:
		for slot in human_count:
			if local_players[slot].kart and not local_players[slot].kart.finished and not local_players[slot].kart.retired:
				var problem:=input_router.ready_problem(slot)
				if not problem.is_empty():disconnect_message=problem;hud.show_controls();return
	paused=not paused;get_tree().paused=paused
	input_router.clear_all()
	if split_view:split_view.set_frozen(paused)
	if paused:hud.pause_menu()
	else:hud.clear(hud.modal_root);disconnect_message=""

func _unhandled_input(event: InputEvent) -> void:
	if input_router.capture_slot>=0:return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE:
		if garage_from_pause:cancel_pause_garage()
		elif hud.modal_root.get_child_count()>0 and state in ["menu","garage"]:hud.clear(hud.modal_root)
		elif state=="garage":return_menu()
		else:toggle_pause()

func _process(dt: float) -> void:
	clock+=dt
	if paused:return
	if state=="countdown":
		countdown-=dt
		var beat:=int(ceil(countdown))
		if beat!=last_beep and beat<=3 and beat>0:last_beep=beat;countdown_sound.play()
		if countdown<=0:
			state="race";go_sound.play()
			for kart in karts:kart.active=true
			for slot in human_count:
				if local_players[slot].launch_charged:local_players[slot].kart.boost(.9,"PERFECT LAUNCH")
	elif state in ["race","finishing"]:
		race_time+=dt
		update_slipstream(dt)
		for slot in human_count:
			var local:=local_players[slot]
			var kart:=local.kart
			if not kart:continue
			local.horn_cooldown=maxf(0.,local.horn_cooldown-dt)
			local.announcement_time=maxf(0.,local.announcement_time-dt)
			var direction: Vector3=-kart.global_basis.z*signf(kart.speed)
			if kart.active and direction.dot(circuit.direction(kart.last_s))<-.25 and absf(kart.speed)>3:local.wrong_way+=dt
			else:local.wrong_way=0.
		if human_count==2 and humans_done():finish_race()
		elif human_count==1 and state=="finishing":
			var all_finished:=karts.all(func(kart):return kart.finished or kart.retired)
			if player.retired or all_finished or race_time-player.finish_time>(70. if test_mode or diagnostics_mode else 4.):finish_race()
	if state in ["countdown","race","finishing"] and player:
		for slot in human_count:update_local_camera(local_players[slot],dt)
		wrong_way_time=local_players[0].wrong_way
	if smoke_mode:
		test_tick+=1
		if test_tick==30:run_smoke_checks()
	if test_mode and state in ["race","finishing"] and race_time>circuit.length*3/15.:
		test_errors.append("Autonomous race exceeded route-scaled time limit");complete_test()

func update_slipstream(dt: float) -> void:
	for slot in human_count:
		var local:=local_players[slot]
		var kart:=local.kart
		if not kart:continue
		local.slipstream_cooldown=maxf(0.,local.slipstream_cooldown-dt)
		var drafting:=false
		if kart.active and absf(kart.wheel_motion_speed)>16:
			var forward: Vector3=-kart.global_basis.z
			for other in karts:
				if other==kart or not other.active:continue
				var gap: Vector3=other.position-kart.position
				if gap.dot(forward)>5 and gap.dot(forward)<19 and absf(gap.dot(kart.global_basis.x))<2.4 and forward.dot(-other.global_basis.z)>.85:drafting=true;break
		if drafting:
			local.slipstream_time+=dt;kart.boost_fuel=minf(1.,kart.boost_fuel+dt*.13)
			if local.slipstream_time>.8 and local.slipstream_cooldown<=0:announce_player(slot,"SLIPSTREAM / NITRO CHARGING",1.4);local.slipstream_cooldown=5.
		else:local.slipstream_time=0.
	slipstream_time=local_players[0].slipstream_time;slipstream_cooldown=local_players[0].slipstream_cooldown

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
	# Legacy 1.6 best_time_astra is deliberately preserved in the loaded config.
	for local in local_players:cfg.set_value("local_players",str(local.slot),local.selection())
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
		legacy_best_time = cfg.get_value("game", "best_time_astra", 0.0)
		for local in local_players:
			var data: Variant=cfg.get_value("local_players",str(local.slot),{})
			if data is Dictionary:local.restore(data,catalog)
		if cfg.get_value("display", "fullscreen", false): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if local_players[0].profile_id==local_players[1].profile_id or local_players[1].profile_id.is_empty():
		local_players[1].profile_id=Crypto.new().generate_random_bytes(16).hex_encode()
	if local_players[0].profile_id.is_empty():local_players[0].profile_id=Crypto.new().generate_random_bytes(16).hex_encode()
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
	check(player.driver.get_meta("visible_driver_id")==&"mario" and player.visual.get_meta("driver_id")==&"mario","Packaged Dacia shows selected Mario cabin driver")
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

func state_for(kart: LeoKart) -> LeoLocalPlayer:
	for local in local_players:
		if local.kart==kart:return local
	return null
func humans_done() -> bool:
	for slot in human_count:
		var kart:=local_players[slot].kart
		if not kart or (not kart.finished and not kart.retired):return false
	return true
func announce_player(slot: int, text: String, duration: float = 1.8) -> void:
	var local:=local_players[slot]
	local.announcement=text;local.announcement_time=duration
	if slot==0:hud.announce(text,duration)
func retire_player(slot: int) -> void:
	var kart:=local_players[slot].kart
	if not kart or kart.finished or kart.retired:return
	kart.retired=true;kart.active=false;kart.boost_time=0;kart.collision_layer=0;kart.collision_mask=1
	announce_player(slot,"RETIRED / DNF",999.)
	if human_count==1:state="finishing"
	if humans_done():
		get_tree().paused=false;paused=false
		finish_race()
func _on_device_lost(slot: int) -> void:
	if state in ["countdown","race","finishing"]:
		disconnect_message="PLAYER %d DISCONNECTED / reassign controls or retire" % (slot+1)
		if not paused:toggle_pause()
		announce_player(slot,disconnect_message,999.)
func _on_local_command(slot: int, action: String) -> void:
	if slot>=human_count:return
	var local:=local_players[slot]
	var kart:=local.kart
	if action=="pause_race":
		if garage_from_pause and slot!=selected_player_slot:return
		if garage_from_pause:cancel_pause_garage()
		else:toggle_pause()
		return
	if paused:return
	if action=="accelerate" and state=="countdown" and countdown>0 and countdown<=1.05:
		local.launch_charged=true
		if slot==0:launch_charged=true
	if not kart or state!="race" or not kart.active:return
	if action=="recover":kart.recover()
	if action=="horn" and local.horn_cooldown<=0:
		local.horn_cooldown=.8;hud.play_arcade_cue("bus_horn" if kart.vehicle_key=="race_bus" else "tuk_horn")
	if action=="photo":
		local.photo=not local.photo
		if slot==0 and human_count==1:hud.photo_mode=local.photo;hud.hud_root.visible=not local.photo
func update_local_camera(local: LeoLocalPlayer, dt: float) -> void:
	if not is_instance_valid(local.camera) or not is_instance_valid(local.kart):return
	var kart:=local.kart
	var view:=local.camera
	var pose: Transform3D=kart.get_global_transform_interpolated()
	local.heading=lerp_angle(local.heading,pose.basis.get_euler().y,1.-exp(-dt*6.))
	var behind:=Vector3(sin(local.heading),0,cos(local.heading))
	view.position=pose.origin+behind*(6.4+absf(kart.speed)*.012+(maxf(0.,kart.definition.collision_size.z-4.)*.5 if human_count==2 else 0.))+Vector3.UP*(3.1+kart.camera_height_offset)
	view.look_at(pose.origin-behind*6.+Vector3.UP*(1.85+kart.camera_height_offset*.5))
	if local.feedback:
		local.feedback.set_boost_active(kart.boost_time>0 and kart.active)
		view.fov=lerpf(view.fov,63.+absf(kart.speed)*.1+float(local.feedback.get_fov_offset()),1.-exp(-dt*12.))
		var target:=0. if reduced_motion else -kart.steer*deg_to_rad(art_profile.camera_roll_degrees)*clampf(absf(kart.speed)/36.,0.,1.)
		local.roll=lerpf(local.roll,target,1.-exp(-dt*6.))
		view.rotate_object_local(Vector3.FORWARD,local.roll+float(local.feedback.get_shake_roll()))
		view.position+=view.global_basis*Vector3(local.feedback.get_shake_offset())
func test_input(action: String, strength: float = 1., slot: int = 0) -> void:
	if not diagnostics_mode and not smoke_mode and not test_mode and not "--drive-test" in OS.get_cmdline_user_args():return
	input_router.players[slot].inject_test(action,strength)

func start_single_player() -> void:
	human_count=1;selected_player_slot=0;input_router.active_slots=1
	var problem:=input_router.ready_problem(0)
	if not problem.is_empty():disconnect_message=problem;hud.show_controls(0);return
	start_race()
func open_local_lobby() -> void:
	return_menu()
	human_count=2;input_router.active_slots=2;input_router.clear_all()
	local_players[0].driver_id=catalog.drivers[selected_driver].id
	local_players[0].vehicle_id=catalog.vehicles[selected_kart].id
	local_players[0].player_name=custom_player_name
	state="lobby";hud.show_lobby()
func try_start_local_race() -> bool:
	for slot in 2:
		var problem:=input_router.ready_problem(slot)
		if not problem.is_empty():
			disconnect_message=problem
			if is_instance_valid(hud.local_lobby):hud.local_lobby.status.text=problem
			return false
	human_count=2
	start_race()
	return true

func diagnostic_run() -> bool:
	return test_mode or smoke_mode or diagnostics_mode or "--drive-test" in OS.get_cmdline_user_args()

func open_rankings() -> bool:
	if diagnostic_run():return false
	if not ranking_store:ranking_store=load("res://scripts/LocalRankingStore.cs").new()
	var ok: bool=ranking_store.open_store(ProjectSettings.globalize_path("user://rankings.sqlite3"))
	ranking_message="" if ok else "RANKINGS SAVE FAILED / Racing is still available. Your existing data is retained."
	return ok

func save_ranking_results() -> void:
	if rankings_written:return
	rankings_written=true
	if race_modified:
		ranking_message="MODIFIED RACE / RECORDS NOT SAVED";return
	if diagnostic_run():
		ranking_message="DIAGNOSTIC RUN / RECORDS NOT SAVED";return
	if not ranking_store:
		ranking_message="RANKINGS SAVE FAILED / Racing is still available.";return
	var rows:=ranking_rows()
	var count: int=ranking_store.save_session(session_id,human_count,rows,false,false)
	ranking_message="RANKINGS SAVE FAILED / Racing is still available. Existing data retained." if count<0 else "OFFLINE RANKINGS / %d RESULTS SAVED" % count
	if count>0 and player.finished:
		best_time=player.finish_time if best_time<=0 else minf(best_time,player.finish_time)

func ranking_rows() -> Array:
	var rows: Array=[]
	for slot in human_count:
		var local:=local_players[slot]
		var kart:=local.kart
		rows.append({"finished":kart.finished,"retired":kart.retired,"next_gate":kart.next_gate,"race_time":kart.finish_time,"best_lap":local.best_lap,"profile_id":local.profile_id,"name":kart.racer_name,"driver":String(kart.visual.get_meta("driver_id")),"vehicle":kart.vehicle_key,"class_id":LeoRaceRules.resolve(kart.definition).class_id,"place":player_place(slot)})
	return rows
