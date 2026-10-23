extends SceneTree
var game: Node3D
func _initialize() -> void: run.call_deferred()
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	await process_frame;await process_frame
	if "--baseline" in OS.get_cmdline_user_args():
		game.diagnostics_mode=true
	else:
		if game.has_method("select_track"):await game.select_track("colombo_city")
	await game.start_race();game.state="capture";game.hud.hide()
	for kart in game.karts:kart.set_physics_process(false)
	var folder:="res://build/city-baseline" if "--baseline" in OS.get_cmdline_user_args() else "res://build/city-captures"
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 5:
		var s:float=game.circuit.length*float(i)/5.
		game.player.place(s,0)
		var direction:Vector3=game.circuit.direction(s)
		game.camera.position=game.player.position-direction*12.+Vector3.UP*5.
		game.camera.look_at(game.player.position+direction*18.+Vector3.UP*2.)
		var streamer: Node3D=game.world.find_child("ColomboSceneryStreaming",true,false)
		if streamer:
			while streamer.busy:await process_frame
			await streamer.refresh(true)
		await create_timer(.4).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/section-%d.png"%i)
	if not "--baseline" in OS.get_cmdline_user_args():
		var views:=[{"name":"lotus-tower","camera":Vector3(230,70,170),"target":Vector3(32,80,-58)},{"name":"galle-face-green","camera":Vector3(-700,65,760),"target":Vector3(-710,3,-100)},{"name":"custom-architecture","camera":Vector3(-270,65,590),"target":Vector3(-225,10,330)},{"name":"lake","camera":Vector3(510,50,170),"target":Vector3(290,0,25)}]
		for view in views:
			game.camera.position=view.camera;game.camera.look_at(view.target)
			var streamer: Node3D=game.world.find_child("ColomboSceneryStreaming",true,false)
			while streamer.busy:await process_frame
			await streamer.refresh(true)
			await create_timer(.3).timeout;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/"+view.name+".png")
	game.return_menu();game.stop_all_audio();game.queue_free();await process_frame;quit()
