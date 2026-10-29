extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=LeoPreviewArt.SIZE;DisplayServer.window_set_size(root.size);Engine.max_fps=60
	var content:=ProjectSettings.globalize_path("res://build/content-baseline/GameAssets")
	if LeoAssets.configure(content)!=OK or LeoAssets.mount_packs()!=OK:printerr(LeoAssets.failure);quit(2);return
	LeoVehicleLibrary.discover()
	var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	game.diagnostics_mode=true;game.set_reduced_motion(true);game.hud.show_garage("home")
	var selector: ModularCarSelector=game.hud.garage_selector
	var variant:="compatibility" if RenderingServer.get_current_rendering_method()=="gl_compatibility" else "forward"
	var output:=ProjectSettings.globalize_path(LeoPreviewArt.ROOT.path_join(variant))
	var only:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preview-vehicle="):only=argument.trim_prefix("--preview-vehicle=")
		if argument.begins_with("--preview-output="):output=argument.trim_prefix("--preview-output=")
	DirAccess.make_dir_recursive_absolute(output)
	for vehicle in game.catalog.vehicles:
		if not only.is_empty() and String(vehicle.id)!=only:continue
		await selector.set_selection(selector.driver_id,vehicle.id);selector.reset_view()
		for frame in 3:await process_frame
		var error:=await selector.capture_art(output.path_join(String(vehicle.id)+"-hero.png"),output.path_join(String(vehicle.id)+".png"))
		if error!=OK:printerr("PREVIEW_CAPTURE_FAILED ",vehicle.id," ",error);await game.quit_game(3);return
		print("ULTRA_PREVIEW ",variant," ",vehicle.id)
	await game.quit_game(0)
