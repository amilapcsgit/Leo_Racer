extends SceneTree
var game: Node3D
var checks:=0
var errors: Array[String]=[]
var samples: Array[float]=[]
var sampling:=false
var stalls: Array[Dictionary]=[]
var phase:="opening"
var output:="res://build/qa260"
func _initialize() -> void:run.call_deferred()
func _process(dt: float) -> bool:
	if sampling:
		samples.append(dt*1000.)
		if dt>.05:stalls.append({"phase":phase,"ms":dt*1000.,"clock":Time.get_ticks_msec()})
	return false
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func capture(name: String) -> void:
	if "--no-captures" in OS.get_cmdline_user_args():return
	var was_sampling:=sampling;sampling=false
	if DisplayServer.get_name()=="headless":sampling=was_sampling;return
	for frame in 5:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
	await process_frame
	await process_frame
	sampling=was_sampling
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1920,1080);DisplayServer.window_set_size(root.size);Engine.max_fps=120
	var assets:=OS.get_environment("LEO_ASSET_ROOT")
	if assets.is_empty():assets=ProjectSettings.globalize_path("res://build/preview260/GameAssets")
	check(LeoAssets.configure(assets)==OK and LeoAssets.mount_packs()==OK,"Shared assets mount")
	LeoVehicleLibrary.discover()
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	if not game.hud:check(false,"Runtime catalog and HUD initialize");quit(2);return
	game.diagnostics_mode=true;game.graphics_quality=1;game.apply_graphics()
	var began:=Time.get_ticks_usec();game.hud.show_garage()
	var ui_ms:=(Time.get_ticks_usec()-began)/1000.
	var selector: ModularCarSelector=game.hud.garage_selector
	check(selector.back_button!=null and selector.next_button!=null,"Garage controls visible immediately")
	sampling=true
	phase="cold selection"
	await selector.set_selection(&"human",&"duster")
	var cold_ms:=(Time.get_ticks_usec()-began)/1000.
	await capture("Duster_My_2014-daylight")
	if not "--no-captures" in OS.get_cmdline_user_args():
		var opened: LeoVehicleFeatures=selector.assembly.get_node("Chassis/VehicleLighting")
		opened.trigger(1);opened.trigger(2)
		for frame in 100:await process_frame
		await capture("Duster_My_2014-open-panels")
		opened.trigger(1);opened.trigger(2)
		for frame in 100:await process_frame
	check(selector.assembly!=null and selector.assembly.get_meta("vehicle_id")==&"duster","Selected Duster appears")
	phase="rapid cycling"
	for id in [&"duster_2024",&"bigster",&"duster_2024",&"duster"]:selector.choose_vehicle(id)
	await selector.set_selection(&"mario",&"duster_2024")
	check(selector.assembly.get_meta("vehicle_id")==&"duster_2024" and selector.assembly.get_meta("driver_id")==&"mario","Rapid cycling discards stale assemblies")
	await capture("Duster_2024-daylight")
	var features: LeoVehicleFeatures=selector.assembly.get_node("Chassis/VehicleLighting")
	features.trigger(1);features.trigger(2)
	phase="idle panels"
	for frame in 100:await process_frame
	await capture("Duster_2024-open-panels")
	selector.hide();await process_frame
	check(LeoPreviewStream.entries.size()<=3,"Bounded preview resource count")
	phase="warm switching"
	selector.show();began=Time.get_ticks_usec();await selector.set_selection(&"human",&"duster_2024")
	var warm_ms:=(Time.get_ticks_usec()-began)/1000.
	sampling=false
	var bridge=load("res://scripts/RaceFeedbackBridge.cs").new();root.add_child(bridge)
	for tier in [1,2]:
		bridge.play_boost_explicit("drift",tier,1.5);bridge._Process(.1)
		check(absf(bridge.get_fov_offset()-(6. if tier==1 else 10.))<.01,"Drift FOV tier "+str(tier))
	bridge.set_reduced_motion(true);check(bridge.get_fov_offset()==0. and bridge.get_shake_offset()==Vector3.ZERO,"Reduced motion suppresses feedback")
	bridge.free()
	game.return_menu();game.selected_kart=game.catalog.vehicle_index(&"duster");game.local_players[0].vehicle_id=&"duster"
	game.set_race_variant("dusk_night");await game.start_race()
	check(game.current_ruleset()=="ultra_v6_dusk_night","Dynamic ranking identity")
	game.state="race"
	for kart in game.karts:kart.active=true;kart.set_physics_process(false)
	var player: LeoKart=game.player
	player.velocity=Vector3.ZERO;player.reset_suspension();player.update_suspension(.016,false)
	player.velocity=Vector3(100,0,-100);player.rotation.y+=1.;player.update_suspension(.016,false)
	check(absf(player.suspension_roll)<=deg_to_rad(5.) and absf(player.suspension_pitch)<=deg_to_rad(3.),"Cosmetic motion limits")
	player.reset_suspension();check(player.suspension_roll==0. and not player.suspension_ready,"Recovery resets filters")
	player.next_gate=LeoCircuit.GATES*2+1;player.progress=game.circuit.length*2.;player.checkpoint_missed=false
	game.race_environment.advance(game.karts,2.,false);var progression: float=game.race_environment.progress
	player.next_gate=1;player.progress=0.;game.race_environment.advance(game.karts,2.,false)
	check(game.race_environment.progress==progression,"Environment progress never regresses")
	var frozen: float=game.race_environment.displayed;game.race_environment.advance(game.karts,5.,true)
	check(game.race_environment.displayed==frozen,"Pause/photo freezes transition")
	game.race_environment.displayed=1.;game.race_environment.apply(true);await capture("Duster_My_2014-night")
	game.race_environment.reset();check(game.race_environment.progress==0.,"Restart resets progression")
	game.set_race_variant("static");game.race_environment.configure(game.world,game.environment,game.chosen_track_id,false)
	check(game.current_ruleset()=="ultra_v6_static","Static ranking identity")
	var store=load("res://scripts/LocalRankingStore.cs").new()
	check(store.open_store(ProjectSettings.globalize_path(output.path_join("rankings.sqlite3"))),"SQLite opens on worker")
	var request: int=store.query_async(1,"arcade_v2","",false,"astra_coast",1,"ultra_v6_static")
	while not store.request_ready(request):await process_frame
	check(store.take_query(request).is_empty(),"Async records return on main thread")
	request=store.query_async(1,"arcade_v2","",false,"astra_coast",1,"ultra_v6_static");store.cancel_request(request)
	store.close_store()
	samples.sort()
	var result:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"ui_ms":ui_ms,"cold_preview_ms":cold_ms,"warm_ms":warm_ms,"garage_worst_ms":samples[-1] if not samples.is_empty() else 0.,"stages":LeoPreviewStream.timings,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name()}
	result.stalls=stalls
	FileAccess.open(output.path_join("runtime.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("RUNTIME260 ",JSON.stringify(result));await game.quit_game(0 if errors.is_empty() else 2)
