extends SceneTree
## The same fresh Kandy split case can run in both 2.7.8 and the candidate.
var game: Node3D
var output:="res://build/qa279/split-probe"
var rows: Array=[]
var viewports: Array[RID]=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1920,1080);DisplayServer.window_set_size(root.size);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=120
	if LeoAssets.configure(OS.get_environment("LEO_ASSET_ROOT"))!=OK or LeoAssets.mount_packs()!=OK:quit(2);return
	LeoVehicleLibrary.discover()
	game=load("res://scenes/main.tscn").instantiate();game.diagnostics_mode=true;root.add_child(game);await game.initialization_finished
	game.return_menu();await game.select_track("kandy_lake")
	game.graphics_quality=1;game.human_count=2;game.selected_kart=game.catalog.vehicle_index(&"bigster")
	game.local_players[0].vehicle_id=&"bigster";game.local_players[1].vehicle_id=&"duster"
	game.local_players[0].camera_view="chase";game.local_players[1].camera_view="chase"
	game.set_race_variant("static");await game.start_race();game.state="race"
	viewports.append(root.get_viewport_rid())
	for viewport in game.split_view.views:viewports.append(viewport.get_viewport_rid())
	for viewport in viewports:RenderingServer.viewport_set_measure_render_time(viewport,true)
	for kart in game.karts:kart.auto_drive=true;kart.active=true
	game.karts[1].place(game.circuit.length*.5,3.)
	await sample("default")
	var scenery: Node3D=game.world.get_node_or_null("SriLankaRoadside279")
	if scenery:
		scenery.hide();scenery.set_process(false)
		await sample("roadside-hidden")
		var originals: Dictionary={};var cache: Dictionary=game.world.get_meta("polish_road_materials279",{})
		for id in cache:
			var original: Object=instance_from_id(int(id))
			if original is Material:originals[cache[id].get_instance_id()]=original
		var restored:=0
		for node in game.world.find_children("*","MeshInstance3D",true,false):
			for index in node.mesh.get_surface_count():
				var material: Material=node.get_active_material(index)
				if material and originals.has(material.get_instance_id()):node.set_surface_override_material(index,originals[material.get_instance_id()]);restored+=1
		if restored>0:await sample("roadside-hidden-original-road-materials")
	var report:={"status":"PASS","renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"resolution":"1920x1080","humans":2,"track":"kandy_lake","rows":rows}
	FileAccess.open(output.path_join("split-probe279.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SPLIT_PROBE279 ",JSON.stringify(report));await game.quit_game()

func sample(label: String) -> void:
	# Put the same two cameras at opposite track stations for every condition.
	game.karts[0].place(0.,-3.);game.karts[1].place(game.circuit.length*.5,3.)
	for slot in 2:game.local_players[slot].camera_rig.reset()
	await create_timer(6.).timeout
	var values: Array[float]=[];var began:=Time.get_ticks_usec();var previous:=began
	var gpu: Array[float]=[];var render_cpu: Array[float]=[];var script_cpu: Array[float]=[]
	while Time.get_ticks_usec()-began<10000000:
		await process_frame
		var now:=Time.get_ticks_usec();values.append((now-previous)/1000.);previous=now
		var gpu_frame:=0.;var cpu_frame:=RenderingServer.get_frame_setup_time_cpu()
		for viewport in viewports:
			gpu_frame+=RenderingServer.viewport_get_measured_render_time_gpu(viewport)
			cpu_frame+=RenderingServer.viewport_get_measured_render_time_cpu(viewport)
		gpu.append(gpu_frame);render_cpu.append(cpu_frame);script_cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.)
	values.sort();gpu.sort();render_cpu.sort();script_cpu.sort()
	var row:={"condition":label,"p50_ms":values[int(values.size()*.5)],"p95_ms":values[int(values.size()*.95)],"p99_ms":values[int(values.size()*.99)],"peak_ms":values[-1],"frames":values.size(),"gpu_p50_ms":gpu[int(gpu.size()*.5)],"render_cpu_p50_ms":render_cpu[int(render_cpu.size()*.5)],"process_p50_ms":script_cpu[int(script_cpu.size()*.5)],"video_mem_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	rows.append(row);print("SPLIT_PROBE279_CASE ",JSON.stringify(row))
