extends SceneTree
## Real track/surface captures plus bounded, warmed wall-clock presentation probes.
var game: Node3D
var output:="res://build/qa279/render-world-forward"
var checks:=0
var errors: Array[String]=[]
var rows: Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func settle(count: int=30) -> void:
	for frame in count:await process_frame
func capture(label: String) -> void:
	await settle(15);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
func run() -> void:
	var perf:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
		if arg=="--performance":perf=true
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1920,1080);DisplayServer.window_set_size(root.size)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=120
	check(LeoAssets.configure(OS.get_environment("LEO_ASSET_ROOT"))==OK and LeoAssets.mount_packs()==OK,"Verified content mounts")
	LeoVehicleLibrary.discover()
	game=load("res://scenes/main.tscn").instantiate();game.diagnostics_mode=true;root.add_child(game);await game.initialization_finished
	game.graphics_quality=1;game.human_count=1;game.selected_kart=game.catalog.vehicle_index(&"duster")
	for track in ["astra_coast","colombo_city","kandy_lake"]:
		game.return_menu();check(await game.select_track(track),"Select "+track)
		game.set_race_variant("static");await game.start_race();game.state="capture";game.set_process(false)
		for kart in game.karts:kart.set_physics_process(false)
		var scenery: Node3D=game.world.get_node("SriLankaRoadside279")
		for frame in 180:
			if scenery.ready_for_review:break
			await physics_frame
		check(scenery.ready_for_review,"Roadside preparation completes / "+track)
		var roads:=0;var surfaces:=0
		for node in game.world.find_children("*","GeometryInstance3D",true,false):
			if not node.get_meta("road_surface279",false):continue
			roads+=1
			var mesh: Mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh
			for surface in mesh.get_surface_count():
				var material: Material=node.get_active_material(surface) if node is MeshInstance3D else mesh.surface_get_material(surface)
				if material is ShaderMaterial and material.shader.code.contains("uniform float wetness"):
					surfaces+=1;check(is_zero_approx(float(material.get_shader_parameter("wetness"))),"Dry active asphalt / "+track)
		check(roads>0 and surfaces>0,"Runtime road surfaces upgraded / "+track)
		for index in 2:
			var station: float=game.circuit.length*(.08 if index==0 else .39)
			if index==1 and not scenery.placements.is_empty():station=float(scenery.placements[scenery.placements.size()/2].station)-8.
			await viewpoint(station)
			await capture(track+"-day-"+str(index))
		check(await game.race_environment.prepare(self,track,true),"Dynamic lighting resources prepare / "+track)
		game.race_environment.configure(game.world,game.environment,track,true)
		game.race_environment.displayed=1.;game.race_environment.progress=1.;game.race_environment.apply(true)
		game.apply_graphics();game.race_environment.enforce_graphics()
		for probe in game.world.find_children("*","ReflectionProbe",true,false):check(not probe.visible,"Night keeps every stale daylight probe disabled / "+track)
		await viewpoint(game.circuit.length*.08)
		await settle(45)
		for frame in 60:game.race_environment.advance(game.karts,1./60.,false);await process_frame
		await capture(track+"-night")
		if not scenery.placements.is_empty():
			var pocket: Dictionary=scenery.placements[scenery.placements.size()/2]
			game.camera.position=pocket.position+game.circuit.direction(float(pocket.station))*4.+Vector3.UP*2.2
			game.camera.look_at(pocket.position+Vector3.UP*.7)
			await capture(track+"-garden")
		var row:={"track":track,"roads":roads,"road_surfaces":surfaces,"pockets":scenery.placements.size(),"batches":scenery.get_child_count()}
		if perf:
			row.performance=[]
			for night in [false,true]:
				await game.race_environment.prepare(self,track,night)
				game.race_environment.configure(game.world,game.environment,track,night)
				if night:game.race_environment.displayed=1.;game.race_environment.progress=1.;game.race_environment.apply(true)
				row.performance.append(await sample_performance("night" if night else "day"))
		rows.append(row);print("RENDER_WORLD279_TRACK ",JSON.stringify(row))
	if perf:
		game.return_menu();game.human_count=2;game.local_players[1].vehicle_id=&"duster_2024"
		await game.start_race()
		var split_row:={"track":"kandy_lake","humans":2,"performance":[]}
		for night in [false,true]:
			await game.race_environment.prepare(self,"kandy_lake",night)
			game.race_environment.configure(game.world,game.environment,"kandy_lake",night)
			if night:game.race_environment.displayed=1.;game.race_environment.progress=1.;game.race_environment.apply(true)
			split_row.performance.append(await sample_performance("night" if night else "day"))
		rows.append(split_row);print("RENDER_WORLD279_SPLIT ",JSON.stringify(split_row))
	await capture_results()
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"resolution":"1920x1080","graphics_quality":"Medium","results":rows}
	FileAccess.open(output.path_join("render-world279.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("RENDER_WORLD279 ",JSON.stringify(report));await game.quit_game(0 if errors.is_empty() else 1)

func sample_performance(phase: String) -> Dictionary:
	game.state="race";game.set_process(true)
	game.hud.show();game.hud.show_race()
	for kart in game.karts:kart.set_physics_process(true);kart.auto_drive=true;kart.active=true
	await create_timer(6.).timeout
	var samples: Array[float]=[];var now:=Time.get_ticks_usec();var began:=now
	while Time.get_ticks_usec()-began<10000000:
		await process_frame
		var next:=Time.get_ticks_usec();samples.append((next-now)/1000.);now=next
	samples.sort();game.set_process(false)
	for kart in game.karts:kart.set_physics_process(false)
	return {"phase":phase,"p50_ms":samples[int(samples.size()*.5)],"p95_ms":samples[int(samples.size()*.95)],"p99_ms":samples[int(samples.size()*.99)],"peak_ms":samples[-1],"frames":samples.size()}

func viewpoint(station: float) -> void:
	game.player.place(station,0.)
	var direction: Vector3=game.circuit.direction(station)
	game.camera.position=game.player.position-direction*8.5+Vector3.UP*3.
	game.camera.look_at(game.player.position+direction*24.+Vector3.UP*1.4)
	var streamer: Node=game.world.find_child("ColomboSceneryStreaming",true,false)
	if streamer:
		while streamer.busy:await process_frame
		await streamer.refresh(true)
	game.hud.hide()

func capture_results() -> void:
	game.set_process(false)
	for kart in game.karts:kart.set_physics_process(false);kart.active=false
	for slot in 2:
		game.local_players[slot].kart=game.karts[slot];game.karts[slot].finished=true
		game.karts[slot].finish_time=123.456+float(slot)*1.644;game.local_players[slot].best_lap=40.123+float(slot)*.577
	var front: Node=game.hud.frontend
	front.result_reference_session=game.session_id;front.result_reference_time=124.;game.race_modified=false;game.state="results"
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(root.size);game.hud.show()
	for players in [1,2]:
		game.human_count=players;front.show_results();await capture("results-solo" if players==1 else "results-split")
