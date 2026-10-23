extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	await game.select_track("colombo_city");game.diagnostics_mode=true;game.human_count=2
	game.selected_kart=game.catalog.vehicle_index(&"bigster");game.local_players[1].vehicle_id=&"duster"
	await game.start_race();game.state="race"
	for kart in game.karts:kart.active=false;kart.set_physics_process(false)
	game.karts[0].place(game.circuit.length*.15,0.);game.karts[1].place(game.circuit.length*.65,0.)
	DirAccess.make_dir_recursive_absolute("res://build/colombo-visuals/split")
	for size in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080)]:
		root.size=size;DisplayServer.window_set_size(size)
		var streamer=game.world.find_child("ColomboSceneryStreaming",true,false)
		while streamer.busy:await process_frame
		await streamer.refresh(true)
		await create_timer(.35).timeout;await RenderingServer.frame_post_draw
		assert(game.split_view.views[0].get_camera_3d()!=game.split_view.views[1].get_camera_3d())
		root.get_texture().get_image().save_png("res://build/colombo-visuals/split/%dx%d.png"%[size.x,size.y])
	print("COLOMBO_SPLIT_CAPTURE_PASS resolutions=3 separated_players=true")
	await game.quit_game()
