extends SceneTree
## Render consistent UI-only derivatives; vehicle packages and masters stay intact.
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1600,900);DisplayServer.window_set_size(root.size);Engine.max_fps=60
	if LeoAssets.configure(ProjectSettings.globalize_path("res://build/lighting-content/GameAssets"))!=OK or LeoAssets.mount_packs()!=OK:quit(2);return
	LeoVehicleLibrary.discover()
	var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	game.diagnostics_mode=true;game.set_reduced_motion(true);game.hud.show_garage("home")
	var selector: ModularCarSelector=game.hud.garage_selector
	var output:=ProjectSettings.globalize_path("res://assets/ui/art/garage-cars")
	DirAccess.make_dir_recursive_absolute(output)
	for vehicle in game.catalog.vehicles:
		await selector.set_selection(selector.driver_id,vehicle.id);selector.reset_view()
		for frame in 3:await process_frame
		await RenderingServer.frame_post_draw
		var image:=selector.viewport.get_texture().get_image().get_region(Rect2i(330,130,940,550))
		image.resize(376,220,Image.INTERPOLATE_LANCZOS)
		if image.save_png(output.path_join(String(vehicle.id)+".png"))!=OK:quit(3);return
		print("SHOWROOM_THUMBNAIL ",vehicle.id)
	await game.quit_game(0)
