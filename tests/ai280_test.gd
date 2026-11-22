extends SceneTree
var errors: Array[String] = []
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var fixture := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-baseline-ai="): fixture=arg.trim_prefix("--qa-baseline-ai=")
	if fixture.is_empty(): quit(2); return
	var original := GDScript.new()
	original.source_code=FileAccess.get_file_as_string(fixture)
	if original.reload()!=OK: quit(2); return
	var game: Node3D=load("res://scenes/main.tscn").instantiate()
	game.diagnostics_mode=true
	root.add_child(game)
	await game.initialization_finished
	await game.start_race()
	for racer in game.karts: racer.set_physics_process(false)
	var kart: LeoKart=game.player
	kart.active=true
	kart.next_gate=3
	var old_queries := 0
	var new_queries := 0
	var original_us := 0
	var optimized_us := 0
	var checks := 0
	for index in 20:
		for lane in [-3.8,0.,3.8,1.25]:
			for speed in [0.,18.,40.]:
				kart.place(game.circuit.length*index/20.,lane)
				kart.speed=speed
				kart.wheel_motion_speed=speed
				kart.velocity=game.circuit.direction(kart.last_s)*speed
				var old: RefCounted=original.new()
				var current:=LeoRaceAI.new()
				old.reset(130,lane)
				current.reset(130,lane)
				var began:=Time.get_ticks_usec()
				var expected: Dictionary=old.commands(kart,.15)
				original_us += Time.get_ticks_usec()-began
				began=Time.get_ticks_usec()
				var actual:=current.commands(kart,.15)
				optimized_us += Time.get_ticks_usec()-began
				checks += 1
				if actual!=expected: errors.append("AI commands differ at %d / %s / %s" % [index,lane,speed])
				old_queries += old.qa_obstacle_queries
				new_queries += current.qa_obstacle_queries
	print("AI280_TEST ",JSON.stringify({"status":"PASS" if errors.is_empty() else "FAIL","errors":errors,"checks":checks,
		"original_queries":old_queries,"optimized_queries":new_queries,"original_ms":original_us/1000.,"optimized_ms":optimized_us/1000.}))
	await game.quit_game(0 if errors.is_empty() else 1)
