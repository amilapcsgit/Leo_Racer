extends Node
var errors: Array[String]=[]
var checks:=0
var game: Node3D
var out := ""
var root: Window:
 get:return get_tree().root
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	for i in 4:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name+".png"))
func run() -> void:
	out=OS.get_environment("VEHICLE_QA_OUTPUT")
	if out.is_empty():out=ProjectSettings.globalize_path("res://build/vehicle232/cameras")
	DirAccess.make_dir_recursive_absolute(out)
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i.ZERO
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_size(root.size)
	game.diagnostics_mode=true
	for track in ["astra_coast","colombo_city","kandy_lake"]:
		game.return_menu()
		var selected: bool=await game.select_track(track)
		check(selected and game.track_definition.id==track,"Requested track loads: "+track)
		for humans in [1,2]:
			game.human_count=humans;game.selected_kart=game.catalog.vehicle_index(&"bigster");game.local_players[1].vehicle_id=&"bigster"
			await game.start_race();game.state="race";game.input_router.gameplay_enabled=true
			for kart in game.karts:kart.active=true;kart.set_physics_process(false)
			var a: LeoKart=game.karts[0]
			check(a.vehicle_lighting.diagnostics.is_empty(),"Authored features resolve in Windows race")
			check(game.karts.size()==6,"Six racers / "+track+" / "+str(humans))
			game._on_local_command(0,"headlights");game._on_local_command(0,"vehicle_action_1")
			check(not a.vehicle_lighting.headlights_on and a.vehicle_lighting.actions[0].open,"Assigned commands reach player's car")
			if humans==2:
				check(game.karts[1].vehicle_lighting.headlights_on and not game.karts[1].vehicle_lighting.actions[0].open,"P1 feature commands isolated from P2")
				game.karts[1].place(game.circuit.length*.5,0.);game.local_players[1].heading=game.karts[1].rotation.y
			a.speed=-4.
			game.local_players[0].camera_rig.advance(-4.,a.control_input,.2)
			game.update_local_camera(game.local_players[0],.5)
			var rig=game.local_players[0].camera_rig
			check(rig.reverse_view and rig.mode=="reverse","Automatic reverse view / "+track)
			var delta: Vector3=game.local_players[0].camera.position-a.global_position
			check(delta.dot(-a.global_basis.z)>1.,"Reverse camera is ahead of car / "+track)
			await capture(track+"-"+str(humans)+"-reverse")
			a.speed=5.;a.control_input.inject_test("look_back",1.);game.update_local_camera(game.local_players[0],.2)
			check(rig.mode=="look_back","Manual rearward look / "+track)
			a.control_input.mouse_orbit=Vector2(90,-20);game.update_local_camera(game.local_players[0],.2)
			check(rig.mode=="orbit","Mouse orbit overrides look-back / "+track)
			if humans==2:check(game.local_players[1].camera_rig.mode=="chase","Other player's camera stays in chase")
			a.control_input.clear();game.update_local_camera(game.local_players[0],1.2)
			check(rig.mode=="chase","Camera recenters / "+track)
			game.toggle_pause();check(a.control_input.mouse_orbit==Vector2.ZERO,"Pause clears orbit input");game.toggle_pause()
			# Deliberate wall across the chase-camera boom tests flat-course clipping.
			rig.angle=0.;rig.reverse_view=false;game.local_players[0].heading=a.rotation.y
			var wall:=StaticBody3D.new();wall.collision_layer=1
			var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(20,20,.5);shape.shape=box;wall.add_child(shape);game.add_child(wall)
			wall.position=a.position+a.global_basis.z*3.+Vector3.UP*2.;wall.rotation.y=a.rotation.y
			await get_tree().physics_frame;await get_tree().physics_frame
			game.update_local_camera(game.local_players[0],.016)
			check(game.local_players[0].camera.position.distance_to(a.position)<5.,"Camera avoids wall / "+track)
			wall.free();game.return_menu()
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"renderer":RenderingServer.get_current_rendering_method()}
	FileAccess.open(out.path_join("camera-test.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("VEHICLE_CAMERA_TEST ",JSON.stringify(report));await game.quit_game(0 if errors.is_empty() else 2)
