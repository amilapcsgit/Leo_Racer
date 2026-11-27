extends SceneTree

const SPEED := 66.0
const LAPS := 2

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var output := ""
	var mode := "current"
	var args := OS.get_cmdline_user_args()
	var visuals := "--qa-grass-visuals" in args
	var smoke := "--qa-grass-smoke" in args
	for arg in args:
		if arg.begins_with("--qa-output="):
			output = arg.trim_prefix("--qa-output=")
		elif arg.begins_with("--qa-grass="):
			mode = arg.trim_prefix("--qa-grass=")
		elif arg.begins_with("--qa-expect-grass="):
			mode = arg.trim_prefix("--qa-expect-grass=")
	if output.is_empty() or mode not in ["off", "current", "field"]:
		quit(2)
		return
	root.size = Vector2i(1024, 576)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await game.initialization_finished
	game.diagnostics_mode = true
	game.graphics.resolution = root.size
	game.graphics_quality = 2
	game.graphics.environment_detail = 3
	game.selected_laps = 1
	await game.select_track("astra_coast")
	var scenery: LeoTrackEnvironment = game.track_environment
	if scenery.track_id != "astra_coast" or scenery.grass_probe != mode:
		push_error("Requested Astra grass backend unavailable: " + mode)
		await game.quit_game(1)
		return
	var measurements: Array[Dictionary] = []
	for humans in [1, 2]:
		game.human_count = humans
		await game.start_race()
		var field_ready := is_instance_valid(scenery.grass_field) and scenery.grass_field.ready_to_draw
		if field_ready:
			field_ready = scenery.grass_field.views.size() == humans and scenery.grass_field.candidate_instances() > 0
		if game.state != "countdown" or (mode == "field" and not field_ready):
			push_error("Race or grass field did not finish warming up")
			await game.quit_game(1)
			return
		if smoke:
			await game.return_menu()
			continue
		game.state = "race"
		game.set_process(false)
		game.set_physics_process(false)
		game.hud.hide()
		for kart: LeoKart in game.karts:
			kart.set_process(false)
			kart.set_physics_process(false)
		if visuals:
			if field_ready:
				var field: Node3D = scenery.grass_field
				scenery.change_tier(0)
				await process_frame
				if field.draw_distance() != 42.0 or field.draw_density() >= field.profile.split_density:
					push_error("The Low environment preset did not reduce the grass field budget.")
				scenery.change_tier(2)
			await capture_drive(game, output, mode, humans)
			game.set_process(true)
			game.set_physics_process(true)
			await game.return_menu()
			continue
		var viewports: Array[RID] = [root.get_viewport_rid()]
		for slot in humans:
			var viewport: RID = game.local_players[slot].camera.get_viewport().get_viewport_rid()
			if viewport not in viewports:
				viewports.append(viewport)
		for viewport in viewports:
			RenderingServer.viewport_set_measure_render_time(viewport, true)
		for lap in LAPS:
			var frames: Array[float] = []
			var gpu: Array[float] = []
			var peak_instances := 0
			var peak_video_bytes := 0
			var elapsed := 0.0
			while elapsed * SPEED < game.circuit.length:
				move_racers(game, elapsed * SPEED, humans)
				var start := Time.get_ticks_usec()
				await process_frame
				var frame := (Time.get_ticks_usec() - start) * 0.001
				frames.append(frame)
				elapsed += frame * 0.001
				var render_ms := 0.0
				for viewport in viewports:
					render_ms += RenderingServer.viewport_get_measured_render_time_gpu(viewport)
				gpu.append(render_ms)
				peak_video_bytes = maxi(peak_video_bytes, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED))
				peak_instances = maxi(peak_instances, candidate_count(scenery))
			measurements.append({"players": humans, "lap": lap + 1, "frames": frames.size(),
				"p50_ms": percentile(frames, 0.50), "p95_ms": percentile(frames, 0.95),
				"p99_ms": percentile(frames, 0.99), "gpu_p50_ms": percentile(gpu, 0.50),
				"gpu_p95_ms": percentile(gpu, 0.95), "peak_candidate_instances": peak_instances,
				"peak_video_bytes": peak_video_bytes})
		for viewport in viewports:
			RenderingServer.viewport_set_measure_render_time(viewport, false)
		game.set_process(true)
		game.set_physics_process(true)
		await game.return_menu()
	var report := {"status": "PASS", "mode": mode, "measurements": measurements, "visuals": visuals,
		"renderer": RenderingServer.get_current_rendering_method(), "gpu": RenderingServer.get_video_adapter_name(),
		"width": root.size.x, "height": root.size.y, "speed_mps": SPEED}
	var suffix := "-smoke" if smoke else ("-visuals" if visuals else "")
	var filename := "grass-pilot-" + mode + suffix + ".json"
	FileAccess.open(output.path_join(filename), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("GRASS_PILOT ", JSON.stringify(report))
	await game.quit_game()

func capture_drive(game: Node3D, output: String, mode: String, humans: int) -> void:
	var circuit: LeoCircuit = game.circuit
	var hairpin := 0.0
	var alignment := 1.0
	for distance in range(30, int(circuit.length) - 30, 6):
		var tangent := circuit.direction(distance - 12).dot(circuit.direction(distance + 12))
		if tangent < alignment:
			alignment = tangent
			hairpin = distance
	var folder := output.path_join("visuals/%s-%dp" % [mode, humans])
	DirAccess.make_dir_recursive_absolute(folder)
	for clip in [["launch", 15.0], ["hairpin", hairpin], ["verge", circuit.length * 0.62]]:
		for frame in range(-18, 18):
			move_racers(game, float(clip[1]) + frame * SPEED / 60.0, humans)
			await process_frame
			await RenderingServer.frame_post_draw
			if frame == -18 or frame >= 0 and frame % 2 == 0:
				var suffix := "cut" if frame == -18 else "%02d" % frame
				var path := folder.path_join("%s-%s.png" % [clip[0], suffix])
				var error := root.get_texture().get_image().save_png(path)
				if error != OK:
					push_error("Could not save grass capture " + path)

func move_racers(game: Node3D, distance: float, humans: int) -> void:
	for index: int in game.karts.size():
		var kart: LeoKart = game.karts[index]
		var offset := 38.0 if index == 1 and humans == 2 else -11.0 * index
		var along := distance + offset
		var lane := 4.0 * sin(along * 0.019 + index)
		var direction: Vector3 = game.circuit.direction(along)
		kart.global_position = game.circuit.sample(along, lane) + Vector3.UP * 0.14
		kart.rotation.y = atan2(-direction.x, -direction.z)
		if index < humans:
			var camera: Camera3D = game.local_players[index].camera
			camera.global_position = kart.global_position - direction * 9.0 + Vector3.UP * 4.0
			camera.look_at(game.circuit.sample(along + 16.0, lane) + Vector3.UP * 1.5)

func candidate_count(scenery: LeoTrackEnvironment) -> int:
	var count := 0
	if is_instance_valid(scenery.grass_field):
		return scenery.grass_field.candidate_instances()
	for batch in scenery.tiles.values():
		count += batch.multimesh.visible_instance_count
	return count

func percentile(values: Array[float], fraction: float) -> float:
	values.sort()
	return values[clampi(ceili(values.size() * fraction) - 1, 0, values.size() - 1)]
