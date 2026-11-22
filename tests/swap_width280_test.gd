extends SceneTree
var errors: Array[String] = []
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	game.diagnostics_mode = true
	root.add_child(game)
	await game.initialization_finished
	await game.start_race()
	game.state = "race"
	var old: LeoKart = game.player
	old.place(100., 2.5)
	var widths: Array = game.circuit.widths.duplicate()
	# A valid varying-width route over the same ground isolates the lane boundary.
	game.circuit.widths.fill(6.)
	game.toggle_pause()
	game.hud.show_garage("pause")
	var changed: bool = game.swap_player_vehicle(&"mario", &"duster", "WIDTH CHECK")
	if not changed:
		errors.append("A safe replacement is available on the narrow road")
	else:
		var fresh: LeoKart = game.player
		var half_width: float = game.circuit.width_at(fresh.last_s)*.5 - fresh.definition.collision_size.x*.5 - .45
		if absf(float(game.circuit.project(fresh.position).offset)) > half_width + .01:
			errors.append("Pause replacement remains inside the actual road width")
		if not is_equal_approx(fresh.last_s,100.): errors.append("Replacement preserves checkpoint distance")
		game.circuit.widths.fill(.5)
		game.toggle_pause()
		game.hud.show_garage("pause")
		if game.swap_player_vehicle(&"mario",&"bigster","TOO WIDE") or game.player != fresh:
			errors.append("Oversized replacement is rejected without replacing the current racer")
	game.circuit.widths = widths
	print("SWAP_WIDTH280_TEST ", JSON.stringify({"status":"PASS" if errors.is_empty() else "FAIL","checks":4,"errors":errors}))
	await game.quit_game(0 if errors.is_empty() else 1)
