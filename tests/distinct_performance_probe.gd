extends SceneTree
var game: Node3D
func _initialize() -> void:run.call_deferred()
func sample(label: String) -> void:
	var frames: Array[float]=[];var physics: Array[float]=[];var draws: Array[float]=[]
	var start := Time.get_ticks_usec();var last := start
	while Time.get_ticks_usec()-start<10000000:
		await process_frame
		var now := Time.get_ticks_usec();frames.append((now-last)/1000.);last=now
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	frames.sort();physics.sort();draws.sort()
	print("PERF_PROBE ",label," ",JSON.stringify({"p50":frames[int(frames.size()*.5)],"p95":frames[int(frames.size()*.95)],"physics_p95":physics[int(physics.size()*.95)],"draw_calls_p95":draws[int(draws.size()*.95)]}))
func run() -> void:
	var assets := OS.get_environment("LEO_ASSET_ROOT")
	assert(LeoAssets.configure(assets)==OK and LeoAssets.mount_packs()==OK)
	LeoVehicleLibrary.discover()
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	game.diagnostics_mode=true;game.return_menu();await game.select_track("kandy_lake")
	game.human_count=2;game.selected_kart=game.catalog.vehicle_index(&"bigster");await game.start_race()
	game.state="race"
	for light in game.world.find_children("*","DirectionalLight3D",true,false):print("PERF_LIGHT ",light.get_path()," shadows=",light.shadow_enabled)
	for kart in game.karts:kart.active=true;kart.auto_drive=true
	game.karts[1].place(game.circuit.length*.5,3.)
	root.size=Vector2i(1920,1080);root.content_scale_size=Vector2i.ZERO;DisplayServer.window_set_size(root.size)
	Engine.max_fps=120;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await create_timer(6.).timeout
	await sample("normal")
	for kart in game.karts:kart.set_physics_process(false)
	await sample("physics_frozen")
	for kart in game.karts:
		if kart.vehicle_key=="bigster":continue
		for mesh in kart.chassis.find_children("*","MeshInstance3D",true,false):
			for i in mesh.mesh.get_surface_count():mesh.set_surface_override_material(i,null)
	await sample("original_materials")
	game.graphics_quality=0;game.apply_graphics()
	await sample("low_graphics")
	await game.quit_game()
