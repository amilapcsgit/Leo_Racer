extends SceneTree
## Measures the same rolling camera stretch on each track and renderer.

const TRACKS := ["astra_coast","colombo_city","kandy_lake","wennappuwa"]
const LEVELS := ["Auto","Low","Medium","High"]
var errors: Array[String] = []
var reports: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1024,576)
	var output := ""
	var selected_tracks: Array = TRACKS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
		if arg.begins_with("--qa-track="): selected_tracks = [arg.trim_prefix("--qa-track=")]
		if arg.begins_with("--qa-resolution="):
			var size := arg.trim_prefix("--qa-resolution=").split("x")
			if size.size() != 2 or not size[0].is_valid_int() or not size[1].is_valid_int(): quit(2); return
			root.size = Vector2i(int(size[0]),int(size[1]))
			if root.size.x < 640 or root.size.y < 480: quit(2); return
	if output.is_empty(): quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await game.initialization_finished
	game.diagnostics_mode = true
	game.graphics.resolution = root.size
	game.graphics_quality = 2
	game.selected_laps = 1
	for track in selected_tracks:
		await game.select_track(track)
		if game.track_definition.id != track:
			errors.append("Could not load "+track)
			continue
		var scenery: LeoTrackEnvironment = game.track_environment
		if scenery.water.is_empty() or scenery.sources.is_empty():
			errors.append("Missing water or grass terrain in "+track+" water="+str(scenery.water.size())+" ground="+str(scenery.sources.size()))
		scenery.set_quality(0,2,false)
		scenery.change_tier(2)
		scenery.apply_window(22.)
		scenery.apply_window(22.)
		if scenery.tier != 1: errors.append("Auto did not lower detail under load")
		for good_window in 16: scenery.apply_window(12.)
		if scenery.tier != 2: errors.append("Auto did not recover after sustained headroom")
		for humans in [1,2]:
			game.human_count = humans
			await game.start_race()
			game.state = "race"
			game.hud.hide()
			for kart in game.karts: kart.set_physics_process(false)
			for setting in [1,2,3,0]:
				game.graphics.environment_detail = setting
				game.apply_graphics()
				var start: float = game.circuit.length * (.12 if track=="kandy_lake" else .08)
				var position: Vector3 = game.circuit.sample(start)
				for slot in humans:
					var camera: Camera3D = game.local_players[slot].camera
					var kart: LeoKart = game.local_players[slot].kart
					kart.place(start + slot*18.0, 0)
					camera.position = position - game.circuit.direction(start)*9. + Vector3(1.8,2.7,0.0)
					camera.look_at(game.circuit.sample(start+19.)+Vector3.UP*1.5)
				for warmup in 60: await process_frame
				var frames: Array[float] = []
				for index in 90:
					var began := Time.get_ticks_usec()
					await process_frame
					frames.append((Time.get_ticks_usec()-began)/1000.)
				frames.sort()
				var count := 0
				for batch in scenery.tiles.values(): count += batch.multimesh.visible_instance_count
				var item := {"track":track,"players":humans,"detail":LEVELS[setting],"tier":scenery.tier,
					"p50_ms":frames[44],"p95_ms":frames[85],"grass":count,"water":scenery.water.size()}
				reports.append(item)
				print("ENVIRONMENT280 ",JSON.stringify(item))
				if humans == 1 and setting == 3 and RenderingServer.get_current_rendering_method() != "dummy":
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output.path_join(track+".png"))
			await game.return_menu()
	var report := {"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),
		"resolution":root.size,"errors":errors,"measurements":reports}
	var file := FileAccess.open(output.path_join("environment280.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("ENVIRONMENT280_DONE ",errors)
	await game.quit_game(0 if errors.is_empty() else 1)
