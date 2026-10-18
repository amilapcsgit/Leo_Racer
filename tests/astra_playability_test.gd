extends SceneTree
var game: Node3D
var errors: Array[String] = []
var checks := 0
var hits := 0
var recoveries := 0
func _initialize() -> void: run.call_deferred()
func verify(ok: bool,label: String) -> void:
	checks += 1
	if not ok: errors.append(label)
	print(("PASS " if ok else "FAIL ")+label)
func ticks(n: int) -> void:
	for i in n: await physics_frame
func press_launch(remaining: float) -> void:
	game.countdown = remaining
	var event := InputEventKey.new()
	event.physical_keycode = KEY_W
	event.pressed = true
	game._unhandled_input(event)
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_race()
	press_launch(2)
	verify(not game.launch_charged,"Early throttle does not award a perfect launch")
	press_launch(.4)
	verify(game.launch_charged,"Final-beat throttle arms the launch boost")
	game._process(.5)
	verify(game.state=="race" and game.player.boost_time>.8,"GO activates one launch envelope")
	var p: LeoKart = game.player
	for kart in game.karts:
		kart.active = false
		kart.set_physics_process(false)
	p.active = true
	p.place(35,0)
	p.wheel_motion_speed = 25
	p.boost_fuel = 0
	var other: LeoKart = game.karts[1]
	other.position = p.position-p.global_basis.z*12
	other.rotation = p.rotation
	other.active = true
	game.update_slipstream(.9)
	verify(p.boost_fuel>.11 and game.slipstream_time>.8,"Following a racer earns measured-speed slipstream fuel")
	verify(game.hud.announcement.contains("SLIPSTREAM"),"Slipstream reward is communicated on HUD")
	other.position += p.global_basis.x*6
	var fuel := p.boost_fuel
	game.update_slipstream(.9)
	verify(is_equal_approx(p.boost_fuel,fuel) and game.slipstream_time==0,"Leaving the draft stops its extra recharge")
	p.wheel_motion_speed = 0
	other.position = p.position-p.global_basis.z*12
	game.update_slipstream(.9)
	verify(is_equal_approx(p.boost_fuel,fuel),"Stationary karts cannot farm slipstream")
	p.impacted.connect(func(_kart,_point,_normal,_strength): hits += 1)
	p.recovered.connect(func(_kart): recoveries += 1)
	other.active = false
	other.collision_layer = 0
	p.place(20,0)
	p.next_gate = 1
	p.boost_time = 0
	p.set_physics_process(true)
	Input.action_press("accelerate")
	await ticks(160)
	verify(hits==0,"Ordinary road contact never produces impact sparks or camera shake")
	Input.action_press("right",.3)
	Input.action_press("drift")
	await ticks(44)
	Input.action_release("right")
	await ticks(8)
	verify(p.drifting and p.drift_charge>.65,"Drift remains latched while its button is held through steering correction")
	Input.action_release("drift")
	await ticks(2)
	verify(p.boost_time>1 and not p.drifting,"Drift release awards its charge tier")
	Input.action_release("accelerate")
	p.place(35,0)
	p.next_gate = 1
	p.boost_time = 0
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8,4,.5)
	shape.shape = box
	wall.add_child(shape)
	root.add_child(wall)
	wall.position = p.position-p.global_basis.z*3+Vector3.UP
	wall.rotation.y = p.rotation.y
	Input.action_press("accelerate")
	await ticks(300)
	Input.action_release("accelerate")
	verify(recoveries>=1,"Prolonged immobility under throttle safely recovers the player")
	verify(p.next_gate==1,"Automatic recovery cannot skip an ordered checkpoint")
	wall.queue_free()
	game.start_race()
	verify(not game.launch_charged and game.slipstream_time==0 and game.horn_cooldown==0,"Restart clears launch, drafting and horn state")
	var data := {"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"floor_impacts":hits,"automatic_recoveries":recoveries}
	FileAccess.open("res://docs/qa-astra/playability.json",FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
	print("ASTRA_PLAYABILITY_REPORT ",JSON.stringify(data))
	game.stop_all_audio()
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if errors.is_empty() else 1)
