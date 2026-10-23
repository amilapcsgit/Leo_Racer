extends SceneTree

var game: Node3D
var errors: Array[String] = []
var checks: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func verify(value: bool, message: String) -> void:
	checks.append(message)
	if not value: errors.append(message)
	print(("PASS " if value else "FAIL ") + message)

func ticks(count: int) -> void:
	for i in count: await physics_frame

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game);await game.initialization_finished
	await process_frame
	await game.start_race()
	game.state = "race"
	for kart in game.karts:
		kart.active = false
		if not kart.is_player: kart.collision_layer = 0
	var p: LeoKart = game.player
	p.active = true
	p.place(12, 0)
	p.next_gate = 1
	Input.action_press("accelerate")
	await ticks(130)
	verify(p.speed > 28 and p.progress > 40, "Throttle accelerates and advances the kart through the world")
	var old_heading := p.rotation.y
	Input.action_press("right", .55)
	await ticks(18)
	verify(p.rotation.y < old_heading - .1, "Right input turns clockwise with speed-sensitive steering")
	Input.action_release("right")
	Input.action_release("accelerate")
	Input.action_press("brake")
	await ticks(70)
	verify(p.speed < 1, "Brake stops forward motion")
	await ticks(80)
	verify(p.speed < -5, "Holding brake engages reverse")
	Input.action_release("brake")
	p.place(85, 0)
	p.next_gate = 1
	Input.action_press("accelerate")
	await ticks(100)
	Input.action_press("drift")
	Input.action_press("right", .35)
	await ticks(52)
	verify(p.drifting and p.drift_charge >= .65, "Drift builds charge only with speed and steering")
	Input.action_release("drift")
	Input.action_release("right")
	await ticks(2)
	verify(p.boost_time > .9 and not p.drifting, "Releasing a charged drift awards a mini-turbo")
	p.boost_time = 0
	p.boost_fuel = 1
	Input.action_press("boost")
	await ticks(2)
	Input.action_release("boost")
	verify(p.boost_time > 1.4 and p.boost_fuel < .05, "Nitro consumes a full meter and starts a speed boost")
	Input.action_release("accelerate")
	p.place(170, 15)
	p.active = false
	await ticks(3)
	var projection: Dictionary = game.circuit.project(p.position)
	verify(absf(projection.offset) <= 9.15, "Continuous barriers recover an out-of-bounds kart without a gap")
	p.next_gate = 6
	p.recover()
	verify(p.next_gate == 6 and p.progress < game.circuit.length, "Recovery preserves the ordered checkpoint sequence")
	game.toggle_pause()
	var frozen_position := p.position
	var frozen_time: float = game.race_time
	await create_timer(.15, true).timeout
	verify(p.position == frozen_position and game.race_time == frozen_time, "Paused race freezes both timer and kart physics")
	game.toggle_pause()
	await game.start_race()
	verify(game.player.speed == 0 and game.player.boost_fuel == 1 and game.player.next_gate == 0, "Restart resets speed nitro and race progress")
	game.stop_all_audio()
	game.return_menu()
	await process_frame
	await process_frame
	var report := {"status":"PASS" if errors.is_empty() else "FAIL", "checks":checks.size(), "errors":errors}
	FileAccess.open("res://docs/drive-test.json", FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("DRIVE_TEST_REPORT ", JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
