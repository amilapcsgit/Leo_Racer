extends SceneTree
var game: Node3D
var output:="res://build/distinct/v3-visual"
var checks:=0
var errors: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func capture(name: String) -> void:
	for i in 5:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output)
	var assets:=OS.get_environment("LEO_ASSET_ROOT")
	assert(LeoAssets.configure(assets)==OK and LeoAssets.mount_packs()==OK)
	LeoVehicleLibrary.discover()
	root.size=Vector2i(1280,720)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	game.diagnostics_mode=true;game.hud.show_garage()
	var garage: ModularCarSelector=game.hud.garage_selector
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/config/vehicle-material-repairs-v1.json"))
	var fleet: Array=[] if "--hud-only" in OS.get_cmdline_user_args() else game.catalog.vehicles
	for raw in fleet:
		var v:=LeoVehiclePresentation.resolve(raw)
		var body:=v.model.instantiate() as Node3D
		preload("res://scripts/catalog/vehicle_finish.gd").install(body,v.visual_profile)
		var original: Dictionary={}
		for node in body.find_children("*","MeshInstance3D",true,false):
			for surface in node.mesh.get_surface_count():original[str(node.get_instance_id())+":"+str(surface)]=node.get_active_material(surface)
		preload("res://scripts/catalog/vehicle_surface_profile.gd").install(body,String(v.id))
		var targets: Array=manifest[String(v.id)].targets
		for node in body.find_children("*","MeshInstance3D",true,false):
			for surface in node.mesh.get_surface_count():
				var repaired:=false
				for target in targets:
					if target.node==String(body.get_path_to(node)) and int(target.surface)==surface:repaired=true
				var material: Material=node.get_active_material(surface)
				check(repaired or original[str(node.get_instance_id())+":"+str(surface)]==material,"Protected surface unchanged / "+String(v.id))
				if repaired:check(material is StandardMaterial3D and material.roughness<.3,"Authored PBR repair / "+String(v.id))
		body.queue_free()
		await garage.set_selection(game.local_players[0].driver_id,v.id)
		check(garage.assembly.scale.is_equal_approx(Vector3.ONE),"Preview assembly remains world scale / "+String(v.id))
		await capture("garage-"+String(v.id))
	game.selected_kart=game.catalog.vehicle_index(&"bigster");game.human_count=1;await game.start_race();game.set_process(false)
	for kart in game.karts:kart.set_physics_process(false)
	game.state="race";game.race_time=54.447;game.player.wheel_motion_speed=31.4
	game.player.place(100.,0.);game.player.wheel_motion_speed=31.4
	await physics_frame;await physics_frame
	game.local_players[0].heading=game.player.rotation.y;game.local_players[0].camera_rig.reset()
	game.update_local_camera(game.local_players[0],1.)
	for i in 20:game.hud._process(.016)
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080)]:
		root.size=resolution;game.hud.resize_canvas()
		await capture("hud-"+str(resolution.x)+"x"+str(resolution.y))
	game.set_reduced_motion(true);await capture("hud-reduced-motion")
	game.human_count=2;await game.start_race();game.set_process(false)
	for kart in game.karts:kart.set_physics_process(false)
	root.size=Vector2i(1920,1080)
	for local in game.local_players:game.update_local_camera(local,1.)
	await capture("hud-split")
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"renderer":RenderingServer.get_current_rendering_method()}
	FileAccess.open(output.path_join("visual.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("V3_VISUAL ",JSON.stringify(report));await game.quit_game(0 if errors.is_empty() else 2)
