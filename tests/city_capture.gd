extends SceneTree
var game: Node3D
func _initialize() -> void: run.call_deferred()
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	if "--baseline" in OS.get_cmdline_user_args():
		game.diagnostics_mode=true
	else:
		if game.has_method("select_track"):await game.select_track("colombo_city")
	game.start_race();game.state="capture"
	for kart in game.karts:kart.set_physics_process(false)
	var folder:="res://build/city-baseline" if "--baseline" in OS.get_cmdline_user_args() else "res://build/city-captures"
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 5:
		var s:float=game.circuit.length*float(i)/5.
		game.player.place(s,0)
		var direction:Vector3=game.circuit.direction(s)
		game.camera.position=game.player.position-direction*12.+Vector3.UP*5.
		game.camera.look_at(game.player.position+direction*18.+Vector3.UP*2.)
		await create_timer(.4).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/section-%d.png"%i)
	game.return_menu();game.stop_all_audio();game.queue_free();await process_frame;quit()
