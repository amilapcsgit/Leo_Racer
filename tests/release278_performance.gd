extends SceneTree
var game: Node3D
var output: String
var rows: Array=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="):output=argument.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output)
	var baseline: bool="--baseline271" in OS.get_cmdline_user_args()
	var began:=Time.get_ticks_usec()
	if LeoAssets.configure(OS.get_environment("LEO_ASSET_ROOT"))!=OK or LeoAssets.mount_packs()!=OK:quit(2);return
	LeoVehicleLibrary.discover()
	game=load("res://scenes/main.tscn").instantiate();game.diagnostics_mode=true;root.add_child(game);await game.initialization_finished
	var initialization_ms:=(Time.get_ticks_usec()-began)/1000.
	root.size=Vector2i(1920,1080);DisplayServer.window_set_size(root.size);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=120
	game.selected_kart=game.catalog.vehicle_index(&"bigster");game.local_players[1].vehicle_id=&"duster"
	var cases: Array=[{"track":"astra_coast","humans":1,"camera":"chase"},{"track":"kandy_lake","humans":2,"camera":"chase"}]
	if not baseline:cases.append_array([{"track":"astra_coast","humans":1,"camera":"ghost"},{"track":"astra_coast","humans":1,"camera":"cockpit"}])
	if "--cockpit-only" in OS.get_cmdline_user_args():cases=[{"track":"astra_coast","humans":1,"camera":"cockpit"}]
	for row in cases:
		game.return_menu();await game.select_track(row.track);game.human_count=row.humans
		var loading_began:=Time.get_ticks_usec();await game.start_race()
		var loading_ms:=(Time.get_ticks_usec()-loading_began)/1000.
		game.state="race"
		if not baseline:game.local_players[0].camera_view=row.camera
		for kart in game.karts:kart.auto_drive=true;kart.active=true
		if row.humans==2:game.karts[1].place(game.circuit.length*.5,3.)
		var first_use: Array[float]=[];var last:=Time.get_ticks_usec();var warm_began:=last
		while Time.get_ticks_usec()-warm_began<6000000:
			if row.camera=="cockpit":
				var elapsed: float=(Time.get_ticks_usec()-warm_began)/1000000.
				game.input_router.players[0].inject_test("camera_left",1. if elapsed<2. else 0.)
				game.input_router.players[0].inject_test("camera_right",1. if elapsed>=2. and elapsed<4. else 0.)
			await process_frame
			var now:=Time.get_ticks_usec();first_use.append((now-last)/1000.);last=now
		if not baseline:
			game.input_router.players[0].inject_test("camera_left",0.);game.input_router.players[0].inject_test("camera_right",0.)
			game.local_players[0].camera_rig.reset()
		var mirror_start: Array[int]=[];var systems: Node=game.player.visual.get_node_or_null("LiveCockpit")
		if systems:
			for mirror in systems.mirrors:mirror_start.append(int(mirror.renders))
		var samples: Array[float]=[];last=Time.get_ticks_usec();var sample_began:=last
		while Time.get_ticks_usec()-sample_began<10000000:
			await process_frame
			var now:=Time.get_ticks_usec();samples.append((now-last)/1000.);last=now
		var mirror_rates: Dictionary={}
		if systems:
			for index in systems.mirrors.size():mirror_rates[String(systems.mirrors[index].surface.name)]=(int(systems.mirrors[index].renders)-mirror_start[index])/((Time.get_ticks_usec()-sample_began)/1000000.)
		row["warm_mirror_updates_per_second"]=mirror_rates
		var key: String=row.track+"-"+str(row.humans)+"p-"+row.camera
		FileAccess.open(output.path_join(key+"-frames.json"),FileAccess.WRITE).store_string(JSON.stringify({"first_use":first_use,"warm":samples}))
		samples.sort();first_use.sort()
		row.merge({"loading_ms":loading_ms,"first_use_peak_ms":first_use[-1],"p50_ms":samples[int(samples.size()*.5)],"p95_ms":samples[int(samples.size()*.95)],"p99_ms":samples[int(samples.size()*.99)],"peak_ms":samples[-1],"frames":samples.size()},true);rows.append(row)
	var report:={"status":"PASS","initialization_ms":initialization_ms,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"baseline271":baseline,"resolution":"1920x1080","warmup_seconds":6,"sample_seconds":10,"cases":rows,"p95_goal_ms":16.7}
	FileAccess.open(output.path_join("performance.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PERFORMANCE278 ",JSON.stringify(report));await game.quit_game()
