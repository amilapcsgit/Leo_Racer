extends Node
var game: Node3D
var checks:=0
var errors: Array[String]=[]
var output:=""
const POINTER=preload("res://scripts/content/content_refresh_check.gd")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func _ready() -> void:run.call_deferred()
func settle(frames: int=4) -> void:
	for frame in frames:await get_tree().process_frame
func capture(name: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	output=ProjectSettings.globalize_path("res://build/qa26-final/polish")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output)
	var assets:=OS.get_environment("LEO_ASSET_ROOT")
	if assets.is_empty():assets=OS.get_executable_path().get_base_dir().path_join("GameAssets")
	check(LeoAssets.configure(assets)==OK and LeoAssets.mount_packs()==OK,"Content mounts")
	LeoVehicleLibrary.discover();game=load("res://scenes/main.tscn").instantiate();get_tree().root.add_child(game);await game.initialization_finished;game.diagnostics_mode=true
	var rig=load("res://scripts/local/race_camera.gd")
	for base in [55.,63.,75.]:
		for speed in [0.,25.,50.,62.5,-50.]:
			for boost in [0.,6.,10.,14.,30.]:
				var previous: float=clampf(base+10.*smoothstep(0.,50.,absf(speed))+boost,base,85.)
				check(is_equal_approx(rig.field_of_view(speed,boost,false,base),base+.1*(previous-base)),"FOV keeps ten percent")
				check(rig.field_of_view(speed,boost,true,base)==base,"Reduced Motion FOV")
			check(is_equal_approx(rig.speed_pullback(speed,false),absf(speed)*.006*.1),"Pullback keeps ten percent")
	game.human_count=1;await game.start_race();game.set_process(false)
	for kart in game.karts:kart.set_physics_process(false)
	var local: LeoLocalPlayer=game.local_players[0];var kart: LeoKart=local.kart
	kart.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	for fps in [30,60,120]:
		for speed in [0.,25.,62.5]:
			kart.position=Vector3(0,1000,0);kart.rotation=Vector3.ZERO;local.heading=0.;local.camera_rig.reset();local.camera.fov=63.
			kart.speed=speed;kart.wheel_motion_speed=speed
			for tick in fps*2:
				kart.position.z-=speed/float(fps);kart.reset_physics_interpolation()
				await get_tree().physics_frame;await get_tree().process_frame
				local.camera_rig.update(local,local.camera,kart,game.input_router.players[0],1./float(fps),game.get_world_3d().direct_space_state,false)
			var box: AABB=rig.body_bounds(kart)
			var expected: float=6.4+rig.speed_pullback(speed,false)+maxf(0.,maxf(box.size.z,kart.definition.collision_size.z)-3.5)*.7
			print("CHASE_DISTANCE ",fps," speed=",speed," camera=",local.camera.position," follow=",local.camera_rig.follow_position," car=",kart.position," expected=",expected)
			check(absf(local.camera_rig.follow_position.z-(kart.position.z+box.get_center().z)-expected)<.02,"Stable following distance / "+str(fps)+"fps / "+str(speed))
	game.set_process(true);game.return_menu();game.hud.show_garage("home")
	var selector: ModularCarSelector=game.hud.garage_selector;selector.set_reduced_motion(true)
	for vehicle in game.catalog.vehicles:
		await selector.set_selection(selector.driver_id,vehicle.id)
		check(is_equal_approx(selector.yaw,0.) and is_equal_approx(selector.pitch,.12) and is_equal_approx(selector.zoom,1.),"Front spawn / "+String(vehicle.id))
		check(is_instance_valid(selector.assembly) and not selector.race_button.disabled,"Ready car / "+String(vehicle.id))
		if String(vehicle.id) in ["bigster","duster","duster_2024"]:await capture("front-"+String(vehicle.id))
	selector.set_reduced_motion(false);selector.reset_view();selector._process(3.9);check(is_zero_approx(selector.yaw),"Four-second display hold")
	selector._process(.2);check(selector.yaw>0.,"Slow rotation starts after hold")
	selector.dragging=true;var yaw:=selector.yaw;selector._process(1.);check(selector.yaw==yaw,"Dragging pauses automatic rotation");selector.dragging=false
	selector.set_reduced_motion(true);selector.reset_view();selector._process(8.);check(is_zero_approx(selector.yaw),"Reduced Motion stops rotation")
	var screen: MeshInstance3D=selector.showroom.get_node("ColomboBackdropScreen");var material: StandardMaterial3D=screen.material_override
	var sampled_aspect:=material.albedo_texture.get_size().aspect()*material.uv1_scale.x/material.uv1_scale.y
	check(absf(sampled_aspect-screen.mesh.size.aspect())<.001,"Skyline pixels preserve physical aspect ratio")
	for extent in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(2560,1080)]:
		get_tree().root.size=extent;DisplayServer.window_set_size(extent);await capture("garage-"+str(extent.x)+"x"+str(extent.y))
	game.return_menu();game.human_count=2;await game.start_race();game.state="race"
	for slot in 2:game.local_players[slot].kart.place(160.+slot*40.,0.);game.local_players[slot].kart.active=true
	for slot in 2:
		for route in ["pointer","keyboard","controller"]:
			game.selected_player_slot=slot;game.toggle_pause();game.hud.show_garage("pause")
			var other: LeoKart=game.local_players[1-slot].kart;var old: LeoKart=game.local_players[slot].kart
			var lap: int=old.lap;var gate: int=old.next_gate;var clock: float=game.race_time
			var id: StringName=&"duster" if old.vehicle_key!="duster" else &"bigster"
			await selector.set_selection(game.local_players[slot].driver_id,id)
			if route=="pointer":await POINTER.click(get_tree(),selector.race_button)
			else:
				selector.race_button.grab_focus()
				for pressed in [true,false]:
					var event: InputEvent=InputEventKey.new() if route=="keyboard" else InputEventJoypadButton.new()
					if event is InputEventKey:event.keycode=KEY_ENTER;event.physical_keycode=KEY_ENTER
					else:event.button_index=JOY_BUTTON_A;event.device=0
					event.pressed=pressed;get_tree().root.push_input(event,true);await get_tree().process_frame
			await settle()
			check(not game.paused and not get_tree().paused and not selector.visible,"Keep Racing dismisses garage / "+route+" / P"+str(slot+1))
			check(selector.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and not selector.is_processing_input(),"Garage rendering and input stop")
			check(game.local_players[slot].kart.vehicle_key==String(id) and game.local_players[1-slot].kart==other,"Swap preserves other player")
			check(game.local_players[slot].kart.lap==lap and game.local_players[slot].kart.next_gate==gate and game.race_time>=clock and game.race_time<clock+1.,"Swap preserves live race progress")
			check(game.input_router.gameplay_enabled,"Racing controls restored")
	game.selected_player_slot=0;game.toggle_pause();game.hud.show_garage("pause")
	var unchanged: LeoKart=game.player;var modified: bool=game.race_modified
	check(game.swap_player_vehicle(game.local_players[0].driver_id,StringName(unchanged.vehicle_key),game.local_players[0].player_name) and game.player==unchanged and game.race_modified==modified,"Unchanged selection resumes same instance")
	game.toggle_pause();game.hud.show_garage("pause");game.input_router.players[0].kind="controller";game.input_router.players[0].device=-1;game.diagnostics_mode=false
	check(not game.swap_player_vehicle(&"human",&"duster","Unavailable controller") and game.paused and selector.policy.visible and not selector.policy.text.is_empty(),"Disconnected device has visible explanation")
	game.diagnostics_mode=true;game.input_router.players[0].kind="keyboard";game.cancel_pause_garage();game.toggle_pause()
	for racer in game.karts:racer.set_physics_process(false)
	var blocker:=StaticBody3D.new();blocker.collision_layer=1
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(100,8,100);collision.shape=shape;blocker.add_child(collision);game.add_child(blocker)
	blocker.global_position=game.circuit.sample(game.player.last_s,0.)+Vector3.UP*2.
	await get_tree().physics_frame;await get_tree().physics_frame
	game.toggle_pause();game.hud.show_garage("pause")
	var blocked_id: StringName=&"duster" if game.player.vehicle_key!="duster" else &"bigster"
	var blocked_old: LeoKart=game.player
	check(not game.swap_player_vehicle(game.local_players[0].driver_id,blocked_id,"Blocked test") and game.paused and game.player==blocked_old and selector.policy.visible and selector.policy.text.contains("safe"),"Blocked placement preserves pause and explains failure")
	blocker.free();game.cancel_pause_garage();game.toggle_pause()
	await capture("race-resumed")
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors}
	FileAccess.open(output.path_join("polish.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("POLISH26 ",JSON.stringify(report));await game.quit_game(0 if errors.is_empty() else 2)
