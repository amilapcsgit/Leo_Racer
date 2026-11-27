extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	game.diagnostics_mode = true
	root.add_child(game)
	await game.initialization_finished
	var results := []
	for definition in game.catalog.vehicles:
		if definition.official:
			continue
		game.return_menu()
		game.selected_kart = game.catalog.vehicle_index(definition.id)
		game.local_players[0].vehicle_id = definition.id
		var showroom: ModularCarSelector = game.hud.garage_selector
		showroom.home_preview = true
		await showroom.set_selection(game.catalog.drivers[game.selected_driver].id, definition.id)
		var preview_ok := is_instance_valid(showroom.assembly) and showroom.assembly.visible
		await game.start_race()
		var car: LeoKart = game.player
		var drive_ok := false
		if is_instance_valid(car) and car.definition.id == definition.id and game.race_modified:
			game.state = "race"
			car.active = true
			car.auto_drive = true
			var start := car.position
			for i in 150:
				await physics_frame
			drive_ok = car.position.distance_to(start) > 10.0 and not car.retired
		results.append({"id": String(definition.id), "showroom": preview_ok, "unranked_drive": drive_ok})
		print("EXPERIMENTAL_CAR ", JSON.stringify(results.back()))
	print("EXPERIMENTAL_CARS ", JSON.stringify(results))
	await game.quit_game()
