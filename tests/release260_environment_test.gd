extends SceneTree
var game: Node3D
var errors: Array[String]=[]
var checks:=0
var output:="res://build/qa260/environment"
var rows: Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func capture(name: String) -> void:
	for frame in 30:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1920,1080);DisplayServer.window_set_size(root.size)
	check(LeoAssets.configure(ProjectSettings.globalize_path("res://build/preview260/GameAssets"))==OK and LeoAssets.mount_packs()==OK,"Environment dependencies mount")
	LeoVehicleLibrary.discover()
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	game.diagnostics_mode=true;game.graphics_quality=1
	for track in ["kandy_lake","astra_coast","colombo_city"]:
		game.return_menu();check(await game.select_track(track),"Select "+track)
		game.human_count=2;game.local_players[0].vehicle_id=&"duster";game.selected_kart=game.catalog.vehicle_index(&"duster");game.local_players[1].vehicle_id=&"duster_2024"
		game.set_race_variant("dusk_night");await game.start_race();game.state="race"
		for kart in game.karts:kart.set_physics_process(false);kart.active=true
		var controller: LeoRaceEnvironment=game.race_environment
		check(controller.enabled and game.current_ruleset()=="distinct_v5_dusk_night"+("+arcade_elevation_v1" if game.track_definition.elevated() else ""),"Dusk identity / "+track)
		if track=="kandy_lake":
			check(controller.neutral.size()==3,"Three neutral Kandy bake resources")
			check(not controller.indirect.is_empty(),"Kandy neutral bakes bound to precincts")
		for slot in 2:
			var local: LeoLocalPlayer=game.local_players[slot]
			local.kart.place(game.circuit.length*.12+slot*7.,-2.+slot*4.);local.heading=local.kart.rotation.y;local.camera_rig.reset()
			local.kart.drafting=true;local.kart.effects.wind._process(0.)
		check(game.local_players[0].kart.effects.wind.layers!=game.local_players[1].kart.effects.wind.layers,"Independent wind layers / "+track)
		game.set_reduced_motion(true)
		for local in game.local_players:
			local.kart.effects.wind._process(0.)
			check(not local.kart.effects.wind.emitting and local.feedback.get_fov_offset()==0.,"Reduced motion resets local feedback / "+track)
		game.set_reduced_motion(false)
		game.player.next_gate=LeoCircuit.GATES*3+1;controller.advance(game.karts,10.,false)
		check(controller.progress==1.,"Validated leader reaches night / "+track)
		controller.displayed=1.;controller.apply(true)
		check(game.environment.ambient_light_energy>.2,"Readable night ambient / "+track)
		game.update_local_camera(game.local_players[0],1.);game.update_local_camera(game.local_players[1],1.)
		await capture(track+"-night-split")
		var before:=controller.displayed;controller.advance(game.karts,3.,true);check(controller.displayed==before,"Frozen transition / "+track)
		var neutral_count:=controller.indirect.size()
		var night_count:=controller.night_lights.size()
		check(game.get_world_3d().environment==game.environment,"Dynamic environment is the active World3D environment / "+track)
		check(night_count>=6,"Authored night-light group / "+track)
		print("ENVIRONMENT_STATE ",track," enabled=",controller.enabled," sky=",game.environment.sky.sky_material," active=",game.get_world_3d().environment==game.environment," sun=",controller.sun.light_energy," night=",night_count)
		game.set_race_variant("static");controller.configure(game.world,game.environment,track,false)
		check(not controller.enabled and controller.original.is_empty() and controller.indirect.is_empty(),"Static state restored / "+track)
		rows.append({"track":track,"neutral_bakes_bound":neutral_count,"night_lights":night_count})
		await capture(track+"-static-split")
	game.return_menu();game.human_count=1;game.graphics_quality=2
	for local_car in [true,false]:
		var car:=LeoKart.new();game.add_child(car);car.setup(game.circuit,0,local_car,"human","duster");car.set_physics_process(false)
		var expected: bool=local_car and RenderingServer.get_current_rendering_method()=="forward_plus"
		check(car.effects.decal_backend==expected,"Only local Forward+ High uses decals")
		check(car.effects.marks.size()<=42,"Skid pool stays bounded")
		for mark in car.effects.marks:check((mark is Decal)==expected,"Exclusive skid backend")
		car.stop_audio();car.queue_free();await process_frame
	# Exercise more cars than the preview LRU can retain and cancel a pending preview.
	game.return_menu();game.hud.show_garage();var selector: ModularCarSelector=game.hud.garage_selector
	for id in [&"duster",&"duster_2024",&"bigster",&"cyberpunk",&"mclaren"]:
		await selector.set_selection(&"human",id)
		check(selector.assembly!=null,"Preview after eviction / "+String(id))
		check(LeoPreviewStream.entries.size()<=3,"LRU resource limit / "+String(id))
	await selector.set_selection(&"human",&"missing_content_fixture")
	check(selector.race_button.disabled and not selector.back_button.disabled,"Missing content keeps Back responsive")
	await selector.set_selection(&"human",&"duster")
	check(selector.assembly!=null and not selector.race_button.disabled,"Valid selection recovers after missing content")
	selector.choose_vehicle(&"duster_2024");selector.hide()
	for frame in 20:await process_frame
	check(not selector.visible,"Closing during load stays closed")
	var result:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"tracks":rows,"renderer":RenderingServer.get_current_rendering_method()}
	FileAccess.open(output.path_join("environment.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("ENVIRONMENT260 ",JSON.stringify(result));await game.quit_game(0 if errors.is_empty() else 2)
