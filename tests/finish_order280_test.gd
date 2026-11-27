extends SceneTree
var errors: Array[String] = []
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	game.diagnostics_mode = true
	root.add_child(game)
	await game.initialization_finished
	game.human_count = 2
	game.selected_laps = 1
	await game.start_race()
	game.state = "race"
	game.race_time = 60.
	var first: LeoKart = game.local_players[1].kart
	var second: LeoKart = game.local_players[0].kart
	first.next_gate = LeoCircuit.GATES + 1
	second.next_gate = LeoCircuit.GATES + 1
	game.on_gate(first, LeoCircuit.GATES)
	game.on_gate(second, LeoCircuit.GATES)
	if game.ranking().find(first) >= game.ranking().find(second):
		errors.append("Equal displayed finish times preserve actual checkpoint crossing order")
	if game.finish_place != 2: errors.append("P1's recorded race placement respects the earlier P2 crossing")
	for i in [5,4,3,2]:
		game.karts[i].next_gate=LeoCircuit.GATES+1
		game.on_gate(game.karts[i],LeoCircuit.GATES)
	if game.ranking().map(func(k):return k.racer_id) != [1,0,5,4,3,2]:
		errors.append("All equal-time finishers retain checkpoint crossing order")
	print("FINISH_ORDER280_TEST ", JSON.stringify({"status":"PASS" if errors.is_empty() else "FAIL","checks":3,"errors":errors}))
	await game.quit_game(0 if errors.is_empty() else 1)
