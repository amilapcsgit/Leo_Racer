extends SceneTree
## Exercise playback through real race setup, including split-screen ownership.
var errors: Array[String] = []
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors.append(message)

func captured_energy(audio: LeoVehicleAudio) -> float:
	for player in audio.layers: player.stop()
	var capture := AudioEffectCapture.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index(audio.bus_name),capture)
	await create_timer(.25,true,false,true).timeout
	var samples := capture.get_buffer(capture.get_frames_available())
	var energy := 0.
	for sample in samples: energy += sample.length_squared()
	return energy/maxi(1,samples.size())

func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	game.diagnostics_mode = true
	root.add_child(game)
	await game.initialization_finished
	for humans in [1, 2]:
		game.human_count = humans
		await game.start_race()
		game.state = "race"
		for slot in humans:
			var kart: LeoKart = game.local_players[slot].kart
			kart.set_physics_process(false)
			kart.set_process(false)
			kart.active = true
			kart.grounded = true
			kart.wheel_motion_speed = 22.
			kart.velocity = Vector3.ZERO
			kart.steer = 0.
			kart.tire_slipping = false
			var audio: LeoVehicleAudio = kart.motor_audio
			var tires: Array[AudioStreamPlayer] = []
			for child in audio.get_children():
				if child is AudioStreamPlayer and child.stream and "tire_" in child.stream.resource_path:
					tires.append(child)
			check(tires.size() == 2, "%dp P%d has recorded scrub and squeal playback" % [humans,slot+1])
			for tire in tires:
				check(tire.playing and tire.bus == audio.bus_name, "Recorded tire plays on its vehicle bus")
				check(tire.stream is AudioStreamWAV and tire.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Recorded tire loops")
			audio.update(1.)
			var quiet: Array[float] = []
			for tire in tires: quiet.append(tire.volume_db)
			kart.steer = 1.
			kart.tire_slipping = true
			kart.velocity = kart.global_basis.x * 6.
			audio.update(1.)
			for i in tires.size(): check(tires[i].volume_db > quiet[i] + 6., "Slip makes the recorded tire layer audible")
			if tires.size()==2:
				check(await captured_energy(audio) > .0000001, "Recorded tires produce a non-silent mixed audio signal")
			kart.active = false
			audio.update(1.)
			for tire in tires: check(tire.volume_db < -65., "Inactive racer silences tire audio")
			audio.stop()
			for tire in tires: check(not tire.playing, "Stopping a vehicle stops tire playback")
		await game.return_menu()
	# An incomplete optional bank must keep the original skid sound usable.
	var original_bank := LeoVehicleAudio.bank.duplicate(true)
	LeoVehicleAudio.bank["tire"] = {"scrub":"missing-tire.wav", "squeal":"tire_squeal.wav"}
	game.human_count = 1
	await game.start_race()
	var fallback: LeoKart = game.local_players[0].kart
	fallback.set_physics_process(false)
	fallback.set_process(false)
	fallback.active = true
	fallback.grounded = true
	fallback.tire_slipping = true
	fallback.motor_audio.update(1.)
	check(fallback.skid != null and fallback.skid.playing and fallback.skid.volume_db > -30., "Incomplete bank retains audible legacy skid playback")
	# Isolate the legacy player from unrelated Effects sounds for the capture.
	var fallback_bus := fallback.skid.bus
	fallback.skid.bus = fallback.motor_audio.bus_name
	check(await captured_energy(fallback.motor_audio) > .0000001, "Legacy fallback produces a non-silent mixed audio signal")
	fallback.skid.bus = fallback_bus
	LeoVehicleAudio.bank = original_bank
	await game.return_menu()
	var report := {"status":"PASS" if errors.is_empty() else "FAIL", "checks":checks, "errors":errors}
	print("TIRE280_TEST ", JSON.stringify(report))
	await game.quit_game(0 if errors.is_empty() else 1)
