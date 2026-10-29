extends SceneTree
var game: Node3D
var output: String
var errors: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:errors.append(text);push_error(text)
func settle(frames: int=16) -> void:
	for frame in frames:await process_frame
	await RenderingServer.frame_post_draw
func shot(label: String) -> void:
	await settle();root.get_texture().get_image().save_png(output.path_join(label+".png"))
func run() -> void:
	var renderer:=RenderingServer.get_current_rendering_method()
	output=ProjectSettings.globalize_path("res://build/qa270/visual-"+renderer)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="):output=argument.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output);Engine.max_fps=60
	var content:=ProjectSettings.globalize_path("res://build/content-baseline/GameAssets") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("GameAssets")
	check(LeoAssets.configure(content)==OK and LeoAssets.mount_packs()==OK,"Content mounted")
	LeoVehicleLibrary.discover()
	game=load("res://scenes/main.tscn").instantiate();game.diagnostics_mode=true;root.add_child(game);await game.initialization_finished
	game.ranking_store=load("res://scripts/LocalRankingStore.cs").new()
	check(game.ranking_store.open_store(ProjectSettings.globalize_path("user://ultra-visual-%d.sqlite3" % Time.get_ticks_usec())),"Isolated visual rankings")
	var rows: Array=[]
	for index in 8:rows.append({"finished":true,"retired":false,"next_gate":25,"race_time":180.+index*4.,"best_lap":55.+index,"profile_id":"pilot-%d" % index,"name":["LEO / COAST CHAMPION","MAYA","KAVI","NADIA","RAVI","ASHAN","LILY","SAM"][index],"driver":"human","vehicle":String(game.catalog.vehicles[index].id),"class_id":"arcade_v2","place":index+1})
	check(game.ranking_store.save_session_for_track("visual",2,rows,false,false,game.track_definition.id,game.track_definition.revision,game.current_ruleset(),3)==8,"Eight leaderboard fixtures")
	for extent in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(2560,1080)]:
		root.size=extent;DisplayServer.window_set_size(extent);await settle()
		var name:="%dx%d" % [extent.x,extent.y]
		game.local_players[0].player_name="ABCDEFGHIJKLMNOPQRSTUVWXYZ123456"
		game.hud.frontend.show_setup(2);await shot("setup-"+name)
		check(game.hud.frontend.start_button.get_global_rect().end.y<=root.get_visible_rect().size.y,"Start Race visible / "+name)
		game.hud.frontend.show_settings();await shot("settings-"+name);game.hud.frontend.close_modal()
		game.hud.frontend.show_records();await shot("records-"+name);game.hud.frontend.close_modal()
		game.hud.frontend.show_tracks();await shot("tracks-"+name);game.hud.frontend.close_modal()
	root.size=Vector2i(900,900);DisplayServer.window_set_size(root.size);await settle()
	game.hud.frontend.show_settings();await shot("settings-narrow")
	var settings_columns:=game.hud.modal_root.find_child("SettingsColumns",true,false) as GridContainer
	check(settings_columns!=null and settings_columns.columns==1,"Narrow settings use one column")
	root.size=Vector2i(1920,1080);DisplayServer.window_set_size(root.size);await settle()
	check(settings_columns.columns==2,"Settings reflow on live window resize")
	game.hud.frontend.close_modal()
	game.local_players[0].player_name="LEO";game.local_players[0].driver_id=&"human";game.local_players[0].vehicle_id=&"import_2019_ford_mustang_rtr_spec5_10th_anniversary"
	game.local_players[1].player_name="MAYA";game.local_players[1].vehicle_id=&"duster_2024"
	game.hud.frontend.show_setup(2);await shot("setup-showcase")
	game.hud.frontend.show_setup(1);await shot("setup-solo")
	game.hud.frontend.open_garage(0)
	var selector: ModularCarSelector=game.hud.garage_selector
	await selector.set_selection(selector.driver_id,&"duster_2024")
	selector.reset_view();await shot("garage-loaded")
	var old_yaw:=selector.yaw;selector.idle=1.9;selector._process(.05)
	check(is_equal_approx(old_yaw,selector.yaw),"Rotation waits two seconds")
	selector._process(.1);check(selector.yaw>old_yaw,"Rotation starts automatically")
	selector.set_reduced_motion(true);old_yaw=selector.yaw;selector._process(3.)
	check(is_equal_approx(old_yaw,selector.yaw),"Reduced Motion disables auto rotation")
	selector.set_reduced_motion(false)
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"renderer":renderer}
	FileAccess.open(output.path_join("visual.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ULTRA_VISUAL_TEST ",JSON.stringify(report));await game.quit_game(0 if errors.is_empty() else 1)
