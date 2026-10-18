extends SceneTree
## Reproducible visual tour. -- --drive-test keeps the personal profile untouched.
var game: Node3D
var destination := "res://docs/qa-colombo"
func _initialize() -> void:
	run.call_deferred()
func capture(label: String) -> void:
	await create_timer(.35).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(destination.path_join(label+".png"))
	print("CAPTURE ",label," ",image.get_size())
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await capture("menu")
	game.hud.show_guide()
	await capture("guide")
	game.hud.clear(game.hud.modal_root)
	game.hud.show_garage()
	await capture("garage")
	game.hud.show_settings()
	await capture("settings")
	game.hud.clear(game.hud.modal_root)
	game.start_race()
	game.state = "capture"
	game.race_time = 3.0
	for kart in game.karts: kart.set_physics_process(false)
	var labels := ["coast","fort","lotus","gardens"]
	for i in range(4):
		var s: float = game.circuit.length*[.04,.29,.55,.79][i]
		game.player.place(s,0)
		var dir: Vector3 = game.circuit.direction(s)
		game.camera.position = game.player.position-dir*7.2+Vector3.UP*3.15
		game.camera.look_at(game.player.position+dir*7+Vector3.UP*1.7)
		game.camera.fov = 66
		await capture(labels[i])
	game.state = "race"
	game.player.active = true
	game.player.speed = 35
	game.player.wheel_motion_speed = 35
	game.player.boost(1.6,"NITRO BOOST")
	await capture("boost")
	game.player.boost_time = 0
	game.player.speed = 29
	game.player.drifting = true
	game.player.drift_charge = 1.6
	game.player.wheel_motion_speed = 29
	game.player.visual.rotation.y = -.25
	game.player.steer = .6
	for i in range(20):
		game.player.global_position -= game.player.global_basis.z*.15
		await process_frame
	await capture("drift")
	game.player.drifting = false
	game.toggle_pause()
	await capture("pause")
	game.toggle_pause()
	game.state = "results"
	game.player.finish_time = 75.321
	game.best_lap = 24.553
	game.hud.show_results()
	await capture("results")
	game.stop_all_audio()
	game.queue_free()
	await process_frame
	await process_frame
	quit()
