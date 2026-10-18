extends SceneTree
var game: Node3D
var errors: Array[String] = []
var checks := 0
func _initialize() -> void:
	run.call_deferred()
func verify(ok: bool,message: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+message)
	if not ok: errors.append(message)
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_race()
	game.state = "race"
	for kart in game.karts: kart.set_physics_process(false)
	game.player.active = true
	game.player.speed = 42
	game.player.wheel_motion_speed = 0
	game.hud._process(.016)
	verify(game.hud.labels.speed.text=="000","Blocked kart reports zero actual speed despite commanded throttle")
	game.player.wheel_motion_speed = 20
	game.hud._process(.016)
	verify(game.hud.labels.speed.text=="072","Speedometer converts measured travel speed to km/h")
	verify(game.art_profile is LeoArtProfile,"Editable Colombo profile is active")
	verify(game.world.find_child("Colombo2026",true,false)!=null,"Additive Colombo scenery is assembled")
	verify(game.world.find_child("SculptedCoastalDunes",true,false).collision_mode==0,"Terrain3D does not change racing collision")
	game.player.boost(1.6,"NITRO BOOST")
	await create_timer(.12).timeout
	verify(game.feedback.get_boost_gain()>0,"Rokojori ignition activates presentation gain")
	verify(game.feedback.get_child_count()==1,"Boost uses one Rokojori sequence")
	verify(game.feedback.get_fov_offset()>8 and game.feedback.get_fov_offset()<=14,"Boost FOV stays inside the requested envelope")
	for i in range(12):
		game.player.boost(1.6,"BOOST PAD")
		await process_frame
	verify(game.feedback.get_child_count()==1,"Repeated boosts replace the previous sequence without accumulation")
	verify(game.feedback.get_fov_offset()<=14,"Repeated boost camera kicks never stack")
	var effects: LeoKartEffects = game.player.effects
	var pool_size := effects.get_child_count()
	game.player.drifting = true
	game.player.drift_charge = 1.0
	game.player.wheel_motion_speed = 22.0
	game.player.global_position += Vector3(0,0,-1)
	effects._process(.03)
	verify(effects.smoke[0].emitting,"Drifting while moving emits tire smoke")
	verify(effects.marks.any(func(mark): return mark.visible and is_equal_approx(mark.global_position.y,.075)),"Drift traces sit above the asphalt instead of following chassis height")
	game.player.drifting = false
	effects._process(.03)
	verify(not effects.smoke[0].emitting,"Smoke stops when drift ends")
	for i in range(20): effects._impact(game.player,game.player.global_position,Vector3.RIGHT,1)
	verify(effects.get_child_count()==pool_size,"Impacts reuse the fixed emitter pool")
	game.player.recover()
	verify(effects.marks.all(func(mark): return not mark.visible),"Recovery immediately clears all road traces")
	verify(game.feedback.get_boost_gain()==0,"Recovery cancels the boost sequence")
	verify(game.feedback.get_recover_glitch()>0,"Recovery plays its brief transition")
	game.paused = true
	paused = true
	var frozen: float = game.feedback.get_recover_glitch()
	await create_timer(.08,true,false,true).timeout
	verify(is_equal_approx(frozen,game.feedback.get_recover_glitch()),"Pause freezes presentation sequence clocks")
	paused = false
	game.paused = false
	game.set_reduced_motion(true)
	game.player.boost(1.6,"NITRO BOOST")
	game.feedback.play_impact(1)
	game.feedback.play_recover()
	verify(game.feedback.get_fov_offset()==0,"Reduced Motion suppresses FOV kicks")
	verify(game.feedback.get_shake_offset()==Vector3.ZERO,"Reduced Motion suppresses camera displacement")
	verify(game.feedback.get_shake_roll()==0,"Reduced Motion suppresses shake roll")
	verify(game.feedback.get_recover_glitch()==0,"Reduced Motion suppresses screen distortion")
	game.set_reduced_motion(false)
	game.start_race()
	await process_frame
	verify(game.feedback.get_child_count()==0,"Restart removes transient Rokojori sequences")
	game.return_menu()
	await process_frame
	verify(game.karts.is_empty(),"Menu return releases racers and their effect pools")
	var report := {"checks":checks,"errors":errors,"status":"PASS" if errors.is_empty() else "FAIL"}
	var file := FileAccess.open("res://docs/qa-colombo/presentation-test.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("PRESENTATION_REPORT ",JSON.stringify(report))
	game.stop_all_audio()
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if errors.is_empty() else 1)
