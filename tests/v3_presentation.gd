extends SceneTree
var game: Node3D
var checks:=0
var errors: Array[String]=[]
var output:="res://build/distinct/v3-presentation"
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func capture(name: String) -> void:
	for i in 5:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output)
	var assets:=OS.get_environment("LEO_ASSET_ROOT")
	assert(LeoAssets.configure(assets)==OK and LeoAssets.mount_packs()==OK)
	LeoVehicleLibrary.discover()
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	game.diagnostics_mode=true
	var forward:=RenderingServer.get_current_rendering_method()=="forward_plus"
	for track_id in ["astra_coast","colombo_city","kandy_lake"]:
		game.return_menu();check(await game.select_track(track_id),"Presentation track loads / "+track_id)
		for humans in [1,2]:
			game.human_count=humans;game.selected_kart=game.catalog.vehicle_index(&"bigster");game.local_players[1].vehicle_id=&"duster"
			await game.start_race();game.set_process(false);game.state="race";game.race_time=20.
			for kart in game.karts:kart.set_physics_process(false);kart.active=true
			for slot in humans:
				var local: LeoLocalPlayer=game.local_players[slot]
				local.kart.place(100. if slot==0 else game.circuit.length*.5,0.)
				local.heading=local.kart.rotation.y;local.camera_rig.reset()
			await physics_frame;await physics_frame
			for slot in humans:game.update_local_camera(game.local_players[slot],1.)
			for quality in 3:
				game.graphics_quality=quality;game.apply_graphics()
				var high: bool=forward and humans==1 and quality==2
				check(game.environment.ssr_enabled==high and game.environment.volumetric_fog_enabled==high,"Renderer quality gate / "+track_id+str(humans)+str(quality))
				for light in game.world.find_children("*","DirectionalLight3D",true,false):
					if light.name=="BakeSun":check(not light.shadow_enabled,"Baked precinct shadow state retained")
				await capture(track_id+"-"+str(humans)+"-"+["low","medium","high"][quality])
			game.set_reduced_motion(true)
			for slot in humans:
				var local: LeoLocalPlayer=game.local_players[slot]
				local.kart.speed=50.;local.kart.wheel_motion_speed=50.
				local.feedback.play_boost("TEST",1.)
				game.update_local_camera(local,.1)
				check(absf(local.camera.fov-game.base_camera_fov)<.001 and local.roll==0.,"Reduced Motion locks base FOV and roll / "+track_id+str(slot))
				local.kart.next_gate=17;local.kart.recover()
				check(local.kart.next_gate==17 and local.kart.progress>=game.circuit.length*2.,"Rendered recovery preserves third lap")
			if humans==2:
				var other: Transform3D=game.local_players[1].camera.transform
				game.update_local_camera(game.local_players[0],.016)
				check(game.local_players[1].camera.transform==other,"Camera presentation remains per player")
			game.toggle_pause();check(game.paused and paused,"Shared pause remains accessible")
			game.toggle_pause();check(not game.paused and not paused,"Shared pause resumes")
			game.set_reduced_motion(false)
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"renderer":RenderingServer.get_current_rendering_method(),"quality_views":18}
	FileAccess.open(output.path_join("presentation.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("V3_PRESENTATION ",JSON.stringify(report));await game.quit_game(0 if errors.is_empty() else 2)
