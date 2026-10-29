extends SceneTree
var game: Node3D
var output:="res://build/qa-lighting/world"
var errors: Array[String]=[]
var checks:=0
var rows: Array=[]
var samples: Array[float]=[]
var sampling:=false
func _initialize() -> void:run.call_deferred()
func _process(dt: float) -> bool:
	if sampling:samples.append(dt*1000.)
	return false
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	for i in 5:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func settled() -> void:
	for frame in 45:await process_frame
func impact() -> Dictionary:
	await settled();samples.clear();sampling=true
	for frame in 3:await process_frame
	var durations: Array=[];var damage_ms: Array=[]
	for slot in game.human_count:
		var kart: LeoKart=game.local_players[slot].kart
		check(not kart.damage.surfaces.is_empty(),"Reviewed damage surface")
		var entry: Dictionary=kart.damage.surfaces[0]
		var arrays: Array=entry.node.mesh.surface_get_arrays(entry.surface)
		var point: Vector3=entry.node.to_global(arrays[Mesh.ARRAY_VERTEX][0])
		var began:=Time.get_ticks_usec();kart.report_contact(point,Vector3.RIGHT,Vector3.LEFT*20.,null,"concrete");durations.append((Time.get_ticks_usec()-began)/1000.)
		damage_ms.append(kart.damage.last_contact_ms)
		check(not kart.damage.patches.is_empty(),"First contact creates damage from the presentation pool")
	for frame in 8:await process_frame
	sampling=false
	return {"callback_ms":durations,"damage_ms":damage_ms,"worst_frame_ms":samples.max(),"warmup":LeoRaceWarmup.last_report}
func run() -> void:
	var selected:="";var impact_only:=false;var players:=2
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
		if arg.begins_with("--lighting-track="):selected=arg.trim_prefix("--lighting-track=")
		if arg.begins_with("--players="):players=int(arg.trim_prefix("--players="))
		if arg=="--impact-only":impact_only=true
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1920,1080);DisplayServer.window_set_size(root.size);Engine.max_fps=120
	check(LeoAssets.configure(OS.get_environment("LEO_ASSET_ROOT") if not OS.get_environment("LEO_ASSET_ROOT").is_empty() else OS.get_executable_path().get_base_dir().path_join("GameAssets"))==OK and LeoAssets.mount_packs()==OK,"Lighting dependencies mount")
	LeoVehicleLibrary.discover();game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	game.diagnostics_mode=true;game.graphics_quality=1
	for track in ([selected] if not selected.is_empty() else ["astra_coast"] if impact_only else ["astra_coast","colombo_city","kandy_lake"]):
		game.return_menu();check(await game.select_track(track),"Select "+track)
		game.human_count=players;game.selected_kart=game.catalog.vehicle_index(&"duster");game.local_players[0].vehicle_id=&"duster";game.local_players[1].vehicle_id=&"duster_2024"
		game.set_race_variant("dusk_night");await game.start_race();game.state="race"
		for kart in game.karts:kart.set_physics_process(false);kart.active=true
		for slot in players:
			var local: LeoLocalPlayer=game.local_players[slot]
			local.kart.place(14.+slot*6.,-2.+slot*4.);local.heading=local.kart.rotation.y;local.camera_rig.reset();game.update_local_camera(local,1.)
		var controller: LeoRaceEnvironment=game.race_environment
		var lights: LeoTrackIllumination=controller.illumination
		check(controller.enabled,"Shared dynamic environment / "+track)
		check(game.get_world_3d().environment==game.environment,"Active environment / "+track)
		check(lights.leds.size()>=5 if track=="astra_coast" else lights.anchors.size()==(87 if track=="kandy_lake" else 197),"Authored landmark or fixture targets / "+track)
		if track!="astra_coast":
			check(lights.pool.size()==(16 if RenderingServer.get_current_rendering_method()=="gl_compatibility" else 24),"Bounded street-light pool")
			for light in lights.pool:check(not light.shadow_enabled,"Shadow-free street beam")
		if track=="kandy_lake":
			check(game.track_definition.revision==2 and game.circuit.boosts.size()==8,"Kandy revision 2 / eight boosters")
			check(game.world.get_node("BoostPads").get_child_count()==8,"Eight visible booster pads")
			check(game.get_tree().get_nodes_in_group("astra_road_decal").size()==7,"Seven inherited road graphics")
			for pad in game.world.get_node("BoostPads").get_children():
				var s: float=game.circuit.project(pad.position).distance;check(pad.basis.y.dot(game.circuit.frame_at(s).y)>.999,"Pad follows elevated road normal")
		if not impact_only:
			for phase in [0.,.5,1.]:
				controller.progress=phase;controller.displayed=phase;controller.apply(true);await settled()
				await capture(track+"-"+str(players)+"p-"+("dusk" if phase==0. else "mid" if phase==.5 else "night"))
			if "--record-transition" in OS.get_cmdline_user_args():await record_transition(track,players)
		controller.progress=1.;controller.displayed=1.;controller.apply(true);await settled()
		var clock:=lights.animation_clock;controller.advance(game.karts,.5,true);check(lights.animation_clock==clock,"Photo freezes LED time")
		game.set_reduced_motion(true);controller.advance(game.karts,.01,false)
		for material in lights.leds:check(float(material.get_shader_parameter("phase"))==0.,"Reduced Motion keeps static LED pattern")
		game.set_reduced_motion(false)
		var result:=await impact();result.track=track;result.players=players;rows.append(result)
		check(LeoRaceWarmup.last_report.particles>0 and LeoRaceWarmup.last_report.damage_materials==6,"Race effects rendered before countdown")
		if not impact_only:
			controller.progress=0.;controller.displayed=0.;game.player.progress=game.circuit.length*1.5;game.player.checkpoint_missed=false
			controller.advance(game.karts,.016,false)
			check(controller.progress>=.5 and controller.displayed>0. and controller.displayed<.02,"Continuous validated progress uses bounded smoothing")
			var phase:=controller.displayed;game.player.progress=0.;controller.advance(game.karts,.016,false);check(controller.displayed>=phase,"Leader transition never reverses")
			game.set_race_variant("static");controller.configure(game.world,game.environment,track,false);check(not controller.enabled and controller.sky_meshes.is_empty(),"Static state restored")
			await capture(track+"-"+str(players)+"p-static")
	var report: Dictionary={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"renderer":RenderingServer.get_current_rendering_method(),"results":rows}
	FileAccess.open(output.path_join("world.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("LIGHTING_WORLD ",JSON.stringify(report));await game.quit_game(0 if errors.is_empty() else 2)

func record_transition(track: String,players: int) -> void:
	var folder:=output.path_join(track+"-"+str(players)+"p-frames")
	DirAccess.make_dir_recursive_absolute(folder)
	var controller: LeoRaceEnvironment=game.race_environment
	controller.reset();controller.illumination.animation_clock=0.
	var start:=Time.get_ticks_msec()
	for index in 120:
		game.player.progress=game.circuit.length*3.*float(index)/119.;game.player.checkpoint_missed=false
		await create_timer(.1).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join("%04d.png"%index))
	FileAccess.open(folder.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"frames":120,"playback_fps":10,"capture_seconds":(Time.get_ticks_msec()-start)/1000.,"source":"actual Godot rendered frames","leader_progress_driven":true,"shared_viewports":players==2}))
