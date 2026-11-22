extends SceneTree
## Full one-lap races at real time: one warm-up then three measured races.
const TRACKS := ["astra_coast", "colombo_city", "kandy_lake", "wennappuwa"]
var output := ""
var rows: Array = []
var errors: Array[String] = []
var selected_tracks: Array = TRACKS
var selected_players: Array = [1, 2]
var repeats := 3
var game: Node3D
var track_load_ms := {}

func _initialize() -> void: run.call_deferred()

func percentile(values: Array[float], fraction: float) -> float:
	return values[clampi(ceili(values.size()*fraction)-1,0,values.size()-1)] if not values.is_empty() else 0.

func save_report(initialization_ms: float) -> void:
	var report := {"status":"PASS" if errors.is_empty() else "FAIL", "errors":errors,
		"renderer":RenderingServer.get_current_rendering_method(), "gpu":RenderingServer.get_video_adapter_name(),
		"initialization_ms":initialization_ms, "resolution":[root.size.x,root.size.y],
		"laps":1, "warmup_races":1, "measured_races":repeats, "time_scale":Engine.time_scale,
		"p95_goal_ms":16.67, "track_load_ms":track_load_ms, "os_process_id":OS.get_process_id(), "cases":rows}
	FileAccess.open(output.path_join("profile.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output=arg.trim_prefix("--qa-output=")
		if arg.begins_with("--qa-track="): selected_tracks=[arg.trim_prefix("--qa-track=")]
		if arg.begins_with("--qa-players="): selected_players=[int(arg.trim_prefix("--qa-players="))]
		if arg.begins_with("--qa-repeats="): repeats=int(arg.trim_prefix("--qa-repeats="))
	if output.is_empty() or repeats < 1 or not selected_players.all(func(n):return n in [1,2]): quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1920,1080)
	DisplayServer.window_set_size(root.size)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	var began := Time.get_ticks_usec()
	if LeoAssets.configure(OS.get_environment("LEO_ASSET_ROOT")) != OK or LeoAssets.mount_packs() != OK: quit(2); return
	LeoVehicleLibrary.discover()
	game=load("res://scenes/main.tscn").instantiate()
	game.diagnostics_mode=true
	root.add_child(game)
	root.close_requested.connect(func(): print("CORE280_WINDOW_CLOSE_REQUEST"))
	await game.initialization_finished
	var initialization_ms := (Time.get_ticks_usec()-began)/1000.
	game.graphics.resolution=root.size
	game.graphics.environment_detail=0
	game.graphics_quality=2
	game.selected_laps=1
	game.selected_kart=game.catalog.vehicle_index(&"bigster")
	game.local_players[1].vehicle_id=&"duster"
	for track in selected_tracks:
		var track_began := Time.get_ticks_usec()
		await game.select_track(track)
		track_load_ms[track] = (Time.get_ticks_usec()-track_began)/1000.
		if String(game.track_definition.id) != track:
			errors.append("Track not loaded: "+track)
			continue
		for humans in selected_players:
			game.human_count=humans
			for repeat_index in range(repeats+1):
				print("CORE280_RACE_BEGIN ",track," ",humans," ",repeat_index)
				var loading_began := Time.get_ticks_usec()
				await game.start_race()
				var loading_ms := (Time.get_ticks_usec()-loading_began)/1000.
				await process_frame
				await process_frame
				game.track_environment.qa_tile_count=0
				game.track_environment.qa_tile_us=0
				game.track_environment.qa_tile_peak_us=0
				game.track_environment.qa_slice_peak_us=0
				game.state="race"
				for kart in game.karts:
					kart.auto_drive=true
					kart.active=true
				var frames: Array[float] = []
				var tiers := {}
				var physics_peak := 0.
				var process_peak := 0.
				var memory_peak := 0.
				var captured := false
				var start := Time.get_ticks_usec()
				var last := start
				while not game.humans_done() and Time.get_ticks_usec()-start < 360000000:
					await process_frame
					var now := Time.get_ticks_usec()
					frames.append((now-last)/1000.)
					last=now
					var tier: int=game.track_environment.tier
					tiers[str(tier)]=int(tiers.get(str(tier),0))+1
					physics_peak=maxf(physics_peak,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.)
					process_peak=maxf(process_peak,Performance.get_monitor(Performance.TIME_PROCESS)*1000.)
					memory_peak=maxf(memory_peak,Performance.get_monitor(Performance.MEMORY_STATIC))
					if repeat_index==1 and not captured and now-start>6000000:
						captured=true
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png(output.path_join(track+"-"+str(humans)+"p.png"))
						last=Time.get_ticks_usec()
				var complete: bool=game.humans_done() and game.local_players.slice(0,humans).all(func(p):return p.kart.finished and not p.kart.retired)
				if not complete: errors.append("Incomplete race: %s %dp run %d" % [track,humans,repeat_index])
				var key := "%s-%dp-%d" % [track,humans,repeat_index]
				FileAccess.open(output.path_join(key+"-frames.json"),FileAccess.WRITE).store_string(JSON.stringify(frames))
				frames.sort()
				var view_sizes: Array = []
				if humans==2:
					for view in game.split_view.views: view_sizes.append({"size":[view.size.x,view.size.y],"scale_3d":view.scaling_3d_scale})
				else: view_sizes.append({"size":[root.size.x,root.size.y],"scale_3d":root.scaling_3d_scale})
				var row := {"track":track,"players":humans,"run":repeat_index,"warmup":repeat_index==0,
					"complete":complete,"frames":frames.size(),"duration_s":(Time.get_ticks_usec()-start)/1000000.,
					"loading_ms":loading_ms,"p50_ms":percentile(frames,.5),"p95_ms":percentile(frames,.95),
					"p99_ms":percentile(frames,.99),"peak_ms":frames[-1] if not frames.is_empty() else 0.,
					"static_memory_peak_bytes":memory_peak,"physics_peak_ms":physics_peak,"process_peak_ms":process_peak,
					"tier_frames":tiers,"views":view_sizes}
				var scenery: LeoTrackEnvironment = game.track_environment
				row["tile_builds"] = scenery.qa_tile_count
				row["tile_metrics_scope"] = "race"
				row["tile_build_total_ms"] = scenery.qa_tile_us / 1000.
				row["tile_build_peak_ms"] = scenery.qa_tile_peak_us / 1000.
				row["tile_slice_peak_ms"] = scenery.qa_slice_peak_us / 1000.
				var queries := 0
				for kart in game.karts: queries += kart.ai.qa_obstacle_queries
				row["ai_obstacle_queries"] = queries
				row["course_length_m"] = game.circuit.length
				row["human_finish_gates"] = game.local_players.slice(0,humans).map(func(p):return p.kart.next_gate)
				rows.append(row)
				print("CORE280_PROFILE ",JSON.stringify(row))
				save_report(initialization_ms)
				await game.return_menu()
				print("CORE280_MENU_RETURN ",track," ",humans," ",repeat_index)
				if not complete: break
	save_report(initialization_ms)
	print("CORE280_PROFILE_DONE ",JSON.stringify({"status":"PASS" if errors.is_empty() else "FAIL","errors":errors}))
	await game.quit_game(0 if errors.is_empty() else 1)
