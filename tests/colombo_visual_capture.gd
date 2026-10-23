extends SceneTree
## Reproducible driving cameras, independent of a saved player's camera settings.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,720)
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game);await game.initialization_finished
	await game.select_track("colombo_city")
	game.diagnostics_mode=true
	await game.start_race();game.state="capture";game.hud.hide()
	for kart in game.karts:kart.set_physics_process(false)
	var phase:="before" if "--before" in OS.get_cmdline_user_args() else "after"
	var folder:="res://build/colombo-visuals/"+phase
	DirAccess.make_dir_recursive_absolute(folder)
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
	var landmarks:=[{"name":"green-and-coast","eye":Vector3(-600,4,120),"at":Vector3(-850,0,15)},
		{"name":"seawall","eye":Vector3(-810,4,200),"at":Vector3(-1000,0,60)},
		{"name":"lotus","eye":Vector3(170,32,130),"at":Vector3(32,65,-58)},
		{"name":"lake","eye":Vector3(470,11,150),"at":Vector3(300,0,25)},
		{"name":"pavilion","eye":Vector3(-160,9,380),"at":Vector3(-110,5,330)}]
	game.player.visible=false
	for view in landmarks:
		game.player.position=view.eye;game.camera.position=view.eye;game.camera.look_at(view.at)
		var streamer=game.world.find_child("ColomboSceneryStreaming",true,false)
		while streamer.busy:await process_frame
		await streamer.refresh(true);await create_timer(.3).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/landmark-"+view.name+".png")
	print("COLOMBO_VISUAL_CAPTURE_COMPLETE ",phase," views=",views.size())
	await game.quit_game()
