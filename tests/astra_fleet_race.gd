extends SceneTree
var game: Node3D
var elapsed := 0.0
var finishing := false
func _initialize() -> void: run.call_deferred()
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.diagnostics_mode = true
	game.start_race()
	for j in range(3):
		var id := 6+j
		var kart := LeoKart.new()
		game.add_child(kart)
		var spec: Dictionary = game.KARTS[1+j]
		kart.setup(game.circuit,id,false,"human",spec.color)
		kart.racer_name = spec.name
		kart.max_speed = 29.0+float(spec.speed)*.9
		kart.acceleration = 13+float(spec.accel)*1.2
		kart.handling = .8+float(spec.grip)*.05
		kart.place(-8-float(id/2)*5.5,-3.2 if id%2==0 else 3.2)
		kart.gate_crossed.connect(game.on_gate)
		game.karts.append(kart)
	game.state = "race"
	game.player.auto_drive = true
	for kart in game.karts: kart.active = true
	Engine.time_scale = 6
func _process(dt: float) -> bool:
	if not game or not game.player or finishing: return false
	elapsed += dt
	if game.karts.all(func(k):return k.finished) or elapsed>370:
		finishing = true
		finish.call_deferred()
	return false
func finish() -> void:
	var rows: Array = []
	var errors: Array[String] = []
	var models: Dictionary = {}
	for kart in game.karts:
		rows.append({"model":kart.vehicle_key,"time":kart.finish_time,"gate":kart.next_gate,"finished":kart.finished,"lap":kart.lap})
		models[kart.vehicle_key] = true
		if not kart.finished or kart.next_gate!=25 or kart.lap!=3: errors.append(kart.vehicle_key+" did not complete three ordered laps")
	if models.size()!=9: errors.append("All nine vehicles must participate")
	var report := {"status":"PASS" if errors.is_empty() else "FAIL","errors":errors,"vehicles":rows,"models":models.size(),"elapsed":elapsed}
	FileAccess.open("res://docs/qa-astra/fleet-race.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("FLEET_RACE_REPORT ",JSON.stringify(report))
	Engine.time_scale = 1
	game.stop_all_audio()
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if errors.is_empty() else 1)
