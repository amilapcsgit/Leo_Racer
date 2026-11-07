extends SceneTree
## Pixel-motion checks use actual mirror textures; performance is sampled apart
## from texture readback so diagnostic synchronization does not distort it.
var game: Node3D
var output := "res://build/qa279/mirrors"
var checks := 0
var errors: Array[String] = []
var motion: Array[Dictionary] = []
var performance: Array[Dictionary] = []
var probes: Array[Dictionary] = []
var animate := false
var animation_started := 0
var performance_active := false
var performance_started := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: errors.append(label);push_error(label)
func settle(frames: int = 12) -> void:
	for frame in frames: await process_frame
func _process(_dt: float) -> bool:
	if animate:
		var elapsed := (Time.get_ticks_usec() - animation_started) / 1000000.0
		for index in probes.size():
			var row: Dictionary = probes[index]
			var camera: Camera3D = row.mirror.camera
			row.node.global_position = camera.global_position - camera.global_basis.z * 4.0 + camera.global_basis.x * sin(elapsed * 2.7 + index) * .45
			row.material.albedo_color = Color.from_hsv(fposmod(elapsed * .41 + index * .23, 1.0), .88, 1.0)
	if performance_active:
		for slot in 2:
			game.input_router.players[slot].inject_test("camera_left", .20 if slot == 0 else 0.0)
			game.input_router.players[slot].inject_test("camera_right", .20 if slot == 1 else 0.0)
	return false

func run() -> void:
	var performance_only := false
	var no_performance := false
	var marketing_photos := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="): output = argument.trim_prefix("--qa-output=")
		if argument == "--performance-only": performance_only = true
		if argument == "--no-performance": no_performance = true
		if argument == "--marketing-photos": marketing_photos = true
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1920,1080);DisplayServer.window_set_size(root.size)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps = 120
	var asset_root := OS.get_environment("LEO_ASSET_ROOT")
	if asset_root.is_empty(): asset_root = ProjectSettings.globalize_path("res://build/content-baseline/GameAssets") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("GameAssets")
	check(LeoAssets.configure(asset_root) == OK and LeoAssets.mount_packs() == OK, "Verified game content mounts")
	LeoVehicleLibrary.discover()
	game = load("res://scenes/main.tscn").instantiate();game.diagnostics_mode = true;root.add_child(game);await game.initialization_finished
	game.graphics_quality = 1
	if not performance_only:
		for id in [&"bigster", &"duster_2024", &"duster"]:
			await start_case(id, 1, false)
			var systems := game.player.visual.get_node("LiveCockpit") as LeoCockpitSystems
			check(systems.mirrors.size() == 3, "Three physical mirrors / " + String(id))
			check(systems.mirrors[0].view.size == Vector2i(128,64), "Solo mirror resolution / " + String(id))
			for row in systems.mirrors:
				check(row.camera.far == 80.0 and row.view.mesh_lod_threshold == 5.0, "Solo mirror distance and LOD / " + String(id))
				check(row.view.positional_shadow_atlas_size == 0 and row.view.msaa_3d == Viewport.MSAA_DISABLED, "Mirror shadow atlas and AA stay disabled / " + String(id))
				check(not row.camera.environment.volumetric_fog_enabled and not row.camera.environment.glow_enabled and not row.camera.environment.ssr_enabled, "Mirror expensive effects stay disabled / " + String(id))
			await measure_motion(String(id) + "-rear", [systems.mirrors[0]], 3.0)
			await capture(String(id) + "-cockpit-forward")
			await verify_inactive(systems, String(id))
			for direction in ["left", "right"]:
				look(0, direction, 1.0)
				await settle(15)
				var row: Dictionary = systems.mirrors[1 if direction == "left" else 2]
				check(systems.mirror_visible(row), "Head-look reveals " + direction + " mirror / " + String(id))
				await measure_motion(String(id) + "-" + direction, [row], 2.0)
				await capture(String(id) + "-look-" + direction)
			look(0, "forward", 0.0)
			if id in [&"bigster", &"duster"]: await capture_exterior(String(id))
		await start_case(&"bigster", 2, true)
		var rear_rows: Array[Dictionary] = []
		for slot in 2:
			var systems := game.local_players[slot].kart.visual.get_node("LiveCockpit") as LeoCockpitSystems
			check(systems.mirrors[0].view.size == Vector2i(64,32), "Split mirror resolution / P" + str(slot + 1))
			check(systems.mirrors[0].camera.far == 60.0 and systems.mirrors[0].view.mesh_lod_threshold == 6.0, "Split mirror distance and LOD / P" + str(slot + 1))
			rear_rows.append(systems.mirrors[0])
			if not systems.mirror_visible(systems.mirrors[0]):
				var before: int = systems.mirrors[0].renders;await settle(15)
				check(systems.mirrors[0].renders == before,"Offscreen split rear mirror stays idle / P" + str(slot + 1))
		# The 2014 center mirror sits to the right of its driver-eye position.
		# Bring its real glass inside the narrower split view before measuring it.
		look(0,"right",.20);look(1,"right",.20);await settle(15)
		for slot in 2:
			var systems := game.local_players[slot].kart.visual.get_node("LiveCockpit") as LeoCockpitSystems
			check(systems.mirror_visible(rear_rows[slot]),"Measured split rear glass is actually onscreen / P" + str(slot + 1))
		await measure_motion("split-night-rear", rear_rows, 3.0)
		await capture("split-night-rear-visible")
		look(0, "left", 1.0);look(1, "right", 1.0)
		await settle(15)
		var left_systems := game.local_players[0].kart.visual.get_node("LiveCockpit") as LeoCockpitSystems
		var right_systems := game.local_players[1].kart.visual.get_node("LiveCockpit") as LeoCockpitSystems
		await measure_motion("split-night-head-look", [left_systems.mirrors[1], right_systems.mirrors[2]], 3.0)
		await capture("split-night-head-look")
	if not no_performance:
		await start_case(&"bigster", 2, true)
		for enabled in [false, true]: await measure_performance(enabled)
	if marketing_photos and performance_only:
		for id in [&"bigster", &"duster"]:
			await start_case(id,1,false);await capture_exterior(String(id))
	var report := {"status":"PASS" if errors.is_empty() else "FAIL", "checks":checks, "errors":errors, "renderer":RenderingServer.get_current_rendering_method(), "gpu":RenderingServer.get_video_adapter_name(), "target_hz":30.0, "motion":motion, "performance":performance}
	FileAccess.open(output.path_join("mirrors279.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("MIRRORS279 ", JSON.stringify(report));await game.quit_game(0 if errors.is_empty() else 1)

func start_case(id: StringName, players: int, night: bool) -> void:
	clear_probes();game.return_menu();game.set_process(true);game.human_count = players
	game.selected_kart = game.catalog.vehicle_index(id);game.local_players[0].vehicle_id = id;game.local_players[1].vehicle_id = &"duster"
	game.set_race_variant("dusk_night" if night else "static")
	await game.start_race();game.set_process(false);game.state = "race";game.race_time = 2.0
	for kart in game.karts: kart.set_physics_process(false);kart.active = false
	for slot in players:
		var local: LeoLocalPlayer = game.local_players[slot]
		local.camera_view = "cockpit";local.photo = false;local.camera_rig.reset();game.update_local_camera(local, 1.0)
	if night:
		game.race_environment.progress = 1.0;game.race_environment.displayed = 1.0;game.race_environment.apply(true)
		for frame in 30: game.race_environment.advance(game.karts, 1.0 / 60.0, false);await process_frame
	await settle(45)

func look(slot: int, direction: String, strength: float) -> void:
	game.input_router.players[slot].inject_test("camera_left", strength if direction == "left" else 0.0)
	game.input_router.players[slot].inject_test("camera_right", strength if direction == "right" else 0.0)
	game.update_local_camera(game.local_players[slot], 1.0)

func add_probe(row: Dictionary, index: int) -> void:
	var node := MeshInstance3D.new();var mesh := SphereMesh.new();mesh.radius = .72;mesh.height = 1.44;node.mesh = mesh
	var material := StandardMaterial3D.new();material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color = Color.MAGENTA
	node.material_override = material;node.layers = 1 << 11;node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;game.world.add_child(node)
	probes.append({"node":node, "material":material, "mirror":row, "index":index})

func clear_probes() -> void:
	animate = false
	for row in probes:
		if is_instance_valid(row.node): row.node.free()
	probes.clear()

func measure_motion(label: String, rows: Array, seconds: float) -> void:
	clear_probes()
	for index in rows.size(): add_probe(rows[index], index)
	animation_started = Time.get_ticks_usec();animate = true;await settle(45)
	var histories: Array[Dictionary] = []
	for row in rows: histories.append({"last_hash":0, "times":[], "images":[], "renders_start":int(row.renders)})
	var began := Time.get_ticks_usec()
	while Time.get_ticks_usec() - began < int(seconds * 1000000.0):
		await process_frame;await RenderingServer.frame_post_draw
		var elapsed := (Time.get_ticks_usec() - began) / 1000000.0
		for index in rows.size():
			var image: Image = rows[index].view.get_texture().get_image()
			var signature := hash(image.get_data())
			var history: Dictionary = histories[index]
			if signature != history.last_hash:
				history.last_hash = signature;history.times.append(elapsed)
				if history.images.size() < 24: history.images.append(image)
	var duration := (Time.get_ticks_usec() - began) / 1000000.0
	for index in rows.size():
		var history: Dictionary = histories[index];var times: Array = history.times
		var actual_hz := float(times.size() - 1) / maxf(.001, float(times[-1]) - float(times[0])) if times.size() > 1 else 0.0
		var requested_hz := float(int(rows[index].renders) - int(history.renders_start)) / duration
		var maximum_gap := 0.0
		for n in range(1, times.size()): maximum_gap = maxf(maximum_gap, float(times[n]) - float(times[n - 1]))
		check(actual_hz >= 29.0, "Actual moving mirror refresh reaches 30 Hz within frame-boundary tolerance / " + label + " / " + str(index))
		check(requested_hz >= 29.0 and requested_hz <= 31.0, "Mirror scheduler stays near 30 Hz without catch-up bursts / " + label + " / " + str(index))
		var owner := rows[index].view.get_parent() as LeoCockpitSystems
		var role := 0 if rows[index].surface.name == "RearLiveMirror" else 1
		var expected_phase := float((owner.kart.local_slot + role) % 2) * LeoCockpitSystems.MIRROR_INTERVAL * .5
		var actual_phase := fposmod(float(rows[index].next_due),LeoCockpitSystems.MIRROR_INTERVAL)
		var phase_error := fposmod(actual_phase - expected_phase + LeoCockpitSystems.MIRROR_INTERVAL * .5,LeoCockpitSystems.MIRROR_INTERVAL) - LeoCockpitSystems.MIRROR_INTERVAL * .5
		check(absf(phase_error) < .0001,"Shared player/role phase is preserved despite different spawn times / " + label + " / " + str(index))
		var record := {"label":label, "mirror":String(rows[index].surface.name), "slot":owner.kart.local_slot, "duration_seconds":duration, "fresh_images":times.size(), "actual_hz":actual_hz, "requested_hz":requested_hz, "max_gap_ms":maximum_gap * 1000.0, "phase_ms":actual_phase * 1000.0, "timestamps_seconds":times, "resolution":str(rows[index].view.size)}
		motion.append(record);print("MIRRORS279_MOTION ", JSON.stringify(record))
		write_contact(label + "-" + str(index), history.images)
	clear_probes()

func write_contact(label: String, images: Array) -> void:
	var folder := output.path_join(label);DirAccess.make_dir_recursive_absolute(folder)
	var contact := Image.create(768,256,false,Image.FORMAT_RGB8);contact.fill(Color("10131b"))
	for index in images.size():
		var raw: Image = images[index];raw.save_png(folder.path_join("frame-%02d.png" % index))
		var cell := raw.duplicate() as Image;cell.resize(128,64,Image.INTERPOLATE_NEAREST);cell.convert(Image.FORMAT_RGB8)
		contact.blit_rect(cell,Rect2i(0,0,128,64),Vector2i((index % 6) * 128,(index / 6) * 64))
	contact.save_png(output.path_join(label + "-motion.png"))

func verify_inactive(systems: LeoCockpitSystems, id: String) -> void:
	var local: LeoLocalPlayer = game.local_players[0]
	for mode in ["chase","ghost"]:
		local.camera_view = mode;game.update_local_camera(local,1.0);await settle(6)
		var before: int = systems.mirrors[0].renders;await create_timer(.25).timeout
		check(systems.mirrors[0].renders == before, "No mirror updates in " + mode + " / " + id)
	local.camera_view = "cockpit";game.update_local_camera(local,1.0);local.photo = true;await settle(6)
	var before: int = systems.mirrors[0].renders;await create_timer(.25).timeout
	check(systems.mirrors[0].renders == before,"Photo mode freezes mirrors / " + id)
	local.photo = false;game.update_local_camera(local,1.0)
	var original := local.camera.global_transform
	local.camera.global_basis = original.basis * Basis(Vector3.UP,PI);await settle(6)
	before = systems.mirrors[0].renders;await create_timer(.25).timeout
	check(systems.mirrors[0].renders == before,"Rear mirror stops when outside the main camera frustum / " + id)
	local.camera.global_transform = original;await settle(2)
	check(systems.mirrors[0].renders > before,"Returning to visible rear mirror refreshes immediately / " + id)
	before = systems.mirrors[0].renders;systems.mirrors[0].next_due = Time.get_ticks_usec()/1000000.0 - .5;systems._process(.5)
	check(systems.mirrors[0].renders - before == 1,"A stalled frame queues one fresh frame, never a catch-up burst / " + id)

func capture(label: String) -> void:
	await settle(5);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))

func capture_exterior(id: String) -> void:
	var local: LeoLocalPlayer = game.local_players[0]
	local.camera_view = "chase";game.update_local_camera(local,1.0);game.hud.hide()
	local.kart.place(150.0,0.0)
	for racer in game.karts:
		if racer != local.kart: racer.hide()
	var pose: Transform3D = local.kart.global_transform
	local.camera.fov = 42.0
	local.camera.global_position = pose * Vector3(3.3,1.6,-4.6)
	local.camera.look_at(pose.origin + Vector3.UP*.9)
	var previous_steer: float = local.kart.steer
	var previous_speed: float = local.kart.wheel_motion_speed
	local.kart.steer = 0.0;local.kart.wheel_motion_speed = 0.0;local.kart.animate_wheels(1.0 / 60.0)
	await capture(id + "-exterior-three-quarter")
	for direction in ["left", "right"]:
		local.kart.steer = .8 if direction == "left" else -.8;local.kart.animate_wheels(1.0 / 60.0)
		for pivot in local.kart.wheel_steering_pivots:
			var expected: float = -local.kart.steer * .35 if pivot.get_meta("front") else 0.0
			check(pivot.basis.x.dot(Basis(Vector3.UP,expected).x) > .9999,"Actual exterior steering pose / " + id + " / " + direction)
		await capture(id + "-exterior-steer-" + direction)
	local.kart.steer = previous_steer;local.kart.wheel_motion_speed = previous_speed;local.kart.animate_wheels(1.0 / 60.0)
	local.camera_view = "cockpit";game.update_local_camera(local,1.0);game.hud.show()

func measure_performance(enabled: bool) -> void:
	var hidden_mirrors: Array[Dictionary] = []
	var tracked_mirrors: Array[Dictionary] = []
	for kart in game.karts: kart.set_physics_process(true);kart.auto_drive = true;kart.active = true
	for slot in 2:
		var local: LeoLocalPlayer = game.local_players[slot]
		local.kart.place(game.circuit.length * float(slot) * .5, -3.0 if slot == 0 else 3.0);local.camera_rig.reset()
		var systems := local.kart.visual.get_node("LiveCockpit") as LeoCockpitSystems
		for row in systems.mirrors:
			row.view.render_target_update_mode = SubViewport.UPDATE_DISABLED
			row.surface.visible = true
			tracked_mirrors.append({"slot":slot,"systems":systems,"row":row,"start":0})
		if not enabled:
			# Keep instrument/navigation work and visible mirror-glass draw calls
			# identical; omit only the mirror scheduler and its viewport renders.
			hidden_mirrors.append({"systems":systems,"rows":systems.mirrors})
			systems.mirrors = []
	performance_active = true;performance_started = Time.get_ticks_usec();game.set_process(true)
	await create_timer(6.0).timeout
	for entry in tracked_mirrors: entry.start = int(entry.row.renders)
	var values: Array[float] = [];var previous := Time.get_ticks_usec();var began := previous
	while Time.get_ticks_usec() - began < 10000000:
		await process_frame
		var now := Time.get_ticks_usec();values.append((now - previous) / 1000.0);previous = now
	performance_active = false;game.set_process(false)
	var duration := (Time.get_ticks_usec() - began) / 1000000.0
	for kart in game.karts: kart.set_physics_process(false)
	for entry in hidden_mirrors: entry.systems.mirrors = entry.rows
	values.sort()
	var rates: Dictionary = {};var phases: Dictionary = {}
	for entry in tracked_mirrors:
		var key := "P" + str(int(entry.slot) + 1) + "/" + String(entry.row.surface.name)
		var rate := float(int(entry.row.renders) - int(entry.start)) / duration
		rates[key] = rate
		if not enabled: check(rate == 0.0,"Disabled mirror baseline performs no mirror renders / " + key)
		elif entry.systems.mirror_visible(entry.row):
			check(rate >= 29.0 and rate <= 31.0,"Native/performance visible mirror retains 30 Hz cadence / " + key)
			var role := 0 if entry.row.surface.name == "RearLiveMirror" else 1
			var expected_phase := float((int(entry.slot) + role) % 2) * LeoCockpitSystems.MIRROR_INTERVAL * .5
			var phase := fposmod(float(entry.row.next_due),LeoCockpitSystems.MIRROR_INTERVAL)
			var error := fposmod(phase - expected_phase + LeoCockpitSystems.MIRROR_INTERVAL * .5,LeoCockpitSystems.MIRROR_INTERVAL) - LeoCockpitSystems.MIRROR_INTERVAL * .5
			check(absf(error) < .0001,"Shared native/performance deadline phase / " + key);phases[key] = phase * 1000.0
	var row := {"mirrors_enabled":enabled, "players":2, "night":true, "head_look":true, "p50_ms":values[int(values.size() * .5)], "p95_ms":values[int(values.size() * .95)], "p99_ms":values[int(values.size() * .99)], "peak_ms":values[-1], "frames":values.size(),"mirror_updates_per_second":rates,"visible_deadline_phases_ms":phases}
	performance.append(row);print("MIRRORS279_PERFORMANCE ",JSON.stringify(row))
