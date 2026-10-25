extends SceneTree
## Reproducible driving cameras, independent of a saved player's camera settings.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,720)
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game);await game.initialization_finished
	await game.select_track("kandy_lake")
	game.diagnostics_mode=true;game.human_count=1
	await game.start_race();game.state="capture";game.hud.hide()
	for kart in game.karts:kart.set_physics_process(false)
	var phase:="before" if "--before" in OS.get_cmdline_user_args() else "compatibility" if "--compat" in OS.get_cmdline_user_args() else "forward"
	var folder:="res://build/kandy/captures/"+phase
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var views: Array=[]
	for i in 12:
		var s:float=game.circuit.length*float(i)/12.
		game.player.place(s,0)
		var direction:Vector3=game.circuit.direction(s)
		game.camera.position=game.player.position-direction*9.+Vector3.UP*3.5
		game.camera.look_at(game.player.position+direction*22.+Vector3.UP*2.)
		var streamer=game.world.find_child("ColomboSceneryStreaming",true,false)
		while streamer.busy:await process_frame
		await streamer.refresh(true)
		await create_timer(.4).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/view-%02d.png"%i)
		views.append({"station":i,"distance_m":s,"camera":str(game.camera.position),"forward":str(direction)})
	FileAccess.open(folder+"/views.json",FileAccess.WRITE).store_string(JSON.stringify(views,"  "))
	print("KANDY_CAPTURE_COMPLETE")
	await game.quit_game()
