extends Node
var game: Node3D
var output:=""
var baseline:=false
var extra_baselines:=false
var rows: Array=[]
var tracks_override: Array=[]
var humans_override: Array=[]
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
		if arg=="--qa-dusk" and game.has_method("set_race_variant"):game.set_race_variant("dusk_night")
		if arg=="--baseline":baseline=true
		if arg=="--extra-baselines":extra_baselines=true
		if arg.begins_with("--qa-track="):tracks_override=[arg.trim_prefix("--qa-track=")]
		if arg.begins_with("--qa-humans="):humans_override=[int(arg.trim_prefix("--qa-humans="))]
	DirAccess.make_dir_recursive_absolute(output)
	print("BENCHMARK_STAGE native_probe ",Time.get_ticks_msec())
	# 2.5 sorted discovery alphabetically; 2.6 sorts by roster. Normalize the
	# diagnostic catalog so index-based AI selection uses identical six cars.
	var roster: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/config/default-roster-v1.json"))
	var ids: Array=roster.vehicles.map(func(row):return String(row.id))
	game.catalog.vehicles.sort_custom(func(a,b):return ids.find(String(a.id))<ids.find(String(b.id)))
	var root:=get_tree().root
	game.diagnostics_mode=true;game.graphics_quality=1
	root.size=Vector2i(1920,1080);root.content_scale_size=Vector2i.ZERO;DisplayServer.window_set_size(root.size)
	Engine.max_fps=120;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for track in (tracks_override if not tracks_override.is_empty() else ["astra_coast","colombo_city"] if extra_baselines else ["kandy_lake"] if baseline else ["kandy_lake","astra_coast","colombo_city"]):
		game.return_menu()
		if game.chosen_track_id!=track:
			var selected: bool=await game.select_track(track)
			if not selected:printerr("BENCHMARK_MAP_FAILED ",track);await game.quit_game(2);return
		if game.track_definition.id!=track:printerr("BENCHMARK_MAP_MISMATCH ",track);await game.quit_game(2);return
		for humans in (humans_override if not humans_override.is_empty() else [1,2]):
			game.human_count=humans;game.selected_kart=game.catalog.vehicle_index(&"bigster");game.local_players[1].vehicle_id=&"duster"
			var start:=Time.get_ticks_msec();await game.start_race();var load_ms:=Time.get_ticks_msec()-start
			game.state="race"
			# Diagnostic switches isolate presentation costs without changing handling.
			if "--qa-hide-hud" in OS.get_cmdline_user_args():
				for instrument in game.hud.find_children("*","LeoRaceInstruments",true,false):instrument.hide();instrument.set_process(false)
				if game.split_view:
					for instrument in game.split_view.overlays:instrument.hide();instrument.set_process(false)
			if "--qa-hide-streets" in OS.get_cmdline_user_args():
				for light in game.race_environment.illumination.pool:light.hide()
			if "--qa-static-hud" in OS.get_cmdline_user_args():
				for instrument in game.split_view.overlays:instrument.set_process(false)
			if humans==1:
				for car in game.karts:car.set_physics_process(false)
				var local: LeoLocalPlayer=game.local_players[0]
				for index in 3:
					local.kart.place(game.circuit.length*[.035,.36,.62][index],0.);local.heading=local.kart.rotation.y;local.camera_rig.reset()
					await get_tree().physics_frame;await get_tree().physics_frame;game.update_local_camera(local,1.)
					# Let streamed scenery settle at each fixed viewpoint in both builds.
					await get_tree().create_timer(2.,true,false,true).timeout
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output.path_join(track+"-showcase-"+str(index)+".png"))
				local.kart.place(-8.,-3.2);local.heading=local.kart.rotation.y;local.camera_rig.reset()
				for car in game.karts:car.set_physics_process(true)
			for kart in game.karts:kart.active=true;kart.auto_drive=true
			if humans==2:game.karts[1].place(game.circuit.length*.5,3.)
			await get_tree().create_timer(6.,true,false,true).timeout
			var measured: Array[RID]=[root.get_viewport_rid()]
			if humans==2:
				for viewport in game.split_view.views:measured.append(viewport.get_viewport_rid())
			if "--qa-gpu" in OS.get_cmdline_user_args():
				for rid in measured:RenderingServer.viewport_set_measure_render_time(rid,true)
			var viewport_gpu:=0.;var viewport_cpu:=0.
			var cpu_process:=0.;var cpu_physics:=0.;var draws:=0.;var primitives:=0.
			var frames: Array[float]=[];var last:=Time.get_ticks_usec();var began:=last
			while Time.get_ticks_usec()-began<(10000000 if "--qa-short" in OS.get_cmdline_user_args() else 30000000):
				await get_tree().process_frame
				var now:=Time.get_ticks_usec();frames.append((now-last)/1000.);last=now
				cpu_process+=Performance.get_monitor(Performance.TIME_PROCESS)*1000.;cpu_physics+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.
				if "--qa-gpu" in OS.get_cmdline_user_args():
					for rid in measured:
						viewport_gpu+=RenderingServer.viewport_get_measured_render_time_gpu(rid);viewport_cpu+=RenderingServer.viewport_get_measured_render_time_cpu(rid)
				draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME);primitives+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			FileAccess.open(output.path_join("frame-times-"+track+"-"+str(humans)+".json"),FileAccess.WRITE).store_string(JSON.stringify(frames))
			frames.sort()
			var result:={"track":track,"actual_track":game.track_definition.id,"track_length":game.circuit.length,"humans":humans,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"resolution":[1920,1080],"warmup_seconds":6,"sample_seconds":30,"p50_ms":frames[int(frames.size()*.5)],"p95_ms":frames[int(frames.size()*.95)],"p99_ms":frames[int(frames.size()*.99)],"max_frame_ms":frames[-1],"load_ms":load_ms,"static_memory_bytes":OS.get_static_memory_usage(),"peak_static_memory_bytes":OS.get_static_memory_peak_usage(),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
			result.cpu_process_mean_ms=cpu_process/frames.size();result.cpu_physics_mean_ms=cpu_physics/frames.size();result.draw_calls_mean=draws/frames.size();result.primitives_mean=primitives/frames.size()
			result.viewport_gpu_ms=viewport_gpu/frames.size();result.viewport_cpu_ms=viewport_cpu/frames.size()
			result.vehicles=game.karts.map(func(car):return car.vehicle_key)
			result.hud_profile=game.split_view.overlays.map(func(item):return {"mean_usec":float(item.profile_usec)/maxi(1,item.profile_frames),"cache_updates":item.background_updates}) if humans==2 else []
			rows.append(result);print("QUALITY26_PERFORMANCE ",JSON.stringify(result))
			FileAccess.open(output.path_join("performance.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
			game.return_menu()
	await game.quit_game()
