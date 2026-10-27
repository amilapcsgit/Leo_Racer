extends SceneTree
func _initialize() -> void:run.call_deferred()
func capture(path: String) -> void:
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var assets := OS.get_environment("LEO_ASSET_ROOT")
	assert(LeoAssets.configure(assets)==OK and LeoAssets.mount_packs()==OK)
	LeoVehicleLibrary.discover()
	root.size=Vector2i(1280,720)
	var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	game.diagnostics_mode=true;game.selected_kart=game.catalog.vehicle_index(&"duster");game.hud.show_garage()
	var garage: ModularCarSelector=game.hud.garage_selector
	var deadline := Time.get_ticks_msec()+30000
	while not is_instance_valid(garage.assembly) and Time.get_ticks_msec()<deadline:await process_frame
	assert(garage.stat_labels.size()==4 and garage.stat_labels[1].text.contains("213"))
	await capture("res://build/distinct/garage-final.png")
	game.return_menu();game.hud.frontend.show_settings()
	await capture("res://build/distinct/settings-final.png")
	print("DISTINCT_VISUAL PASS: garage boost stats and settings render")
	await game.quit_game()
