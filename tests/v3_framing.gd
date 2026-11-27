extends SceneTree
var output:="res://build/distinct/v3-framing"
var vertices: Dictionary={}
func mesh_vertices(vehicle: VehicleDefinition) -> PackedVector3Array:
	if vertices.has(vehicle.id):return vertices[vehicle.id]
	var model:=vehicle.model.instantiate() as Node3D
	model.transform=vehicle.normalization*model.transform
	var points:=PackedVector3Array()
	for node in model.find_children("*","MeshInstance3D",true,false):
		if not node.visible:continue
		var pose:=model.transform*LeoVehicleFeatures.local_pose(node,model)
		for surface in node.mesh.get_surface_count():
			var source: PackedVector3Array=node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point in source:points.append(pose*point)
	model.queue_free();vertices[vehicle.id]=points
	return points
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var rig=load("res://scripts/local/race_camera.gd")
	for speed in [0.,25.,50.,62.5,-50.]:
		assert(is_equal_approx(rig.speed_pullback(speed,false),absf(speed)*.012*.5*.1))
		assert(is_zero_approx(rig.speed_pullback(speed,true)))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output)
	assert(LeoAssets.configure(OS.get_environment("LEO_ASSET_ROOT"))==OK and LeoAssets.mount_packs()==OK)
	LeoVehicleLibrary.discover();root.size=Vector2i(1920,1080)
	var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	game.diagnostics_mode=true;game.selected_kart=game.catalog.vehicle_index(&"bigster");await game.start_race();game.set_process(false)
	for kart in game.karts:kart.set_physics_process(false)
	game.player.place(100.,0.);await physics_frame;await physics_frame
	var rows: Array=[];var errors: Array[String]=[]
	var local: LeoLocalPlayer=game.local_players[0]
	for scenario in 4:
		var humans: int=1+scenario%2
		game.base_camera_fov=55. if scenario>=2 else 63.
		game.set_reduced_motion(scenario>=2)
		game.human_count=humans;game.split_view.activate(humans==2)
		await process_frame;await process_frame
		for raw in game.catalog.vehicles:
			var vehicle:=LeoVehiclePresentation.resolve(raw)
			game.player.definition=vehicle;game.player.camera_height_offset=vehicle.camera_height
			game.player.speed=0.;game.player.wheel_motion_speed=0.;local.heading=game.player.rotation.y;local.camera_rig.reset()
			local.camera.fov=game.base_camera_fov
			game.update_local_camera(local,.5)
			var box: AABB=vehicle.get_meta("presentation_bounds")
			var visible:=true
			var clipped:=Vector3.ZERO
			for corner in 8:
				if not local.camera.is_position_in_frustum(game.player.global_transform*box.get_endpoint(corner)):visible=false
			# A whole-car box includes empty ground-level corners behind the bumper.
			# Test the actual geometry before treating conservative box clipping as a failure.
			if not visible:
				visible=true
				for point in mesh_vertices(vehicle):
					if not local.camera.is_position_in_frustum(game.player.global_transform*point):visible=false;clipped=point;break
			var pixel:=local.camera.unproject_position(game.player.global_transform*clipped)
			rows.append({"id":String(vehicle.id),"humans":humans,"base_fov":game.base_camera_fov,"visible":visible,"clipped_point":LeoVehicleCodec.encode(clipped),"pixel":[pixel.x,pixel.y],"viewport":[local.camera.get_viewport().get_visible_rect().size.x,local.camera.get_viewport().get_visible_rect().size.y]})
			if not visible:errors.append(String(vehicle.id)+" / "+str(humans)+" players / FOV "+str(game.base_camera_fov))
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":rows.size(),"errors":errors,"vehicles":rows}
	FileAccess.open(output.path_join("framing.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("V3_FRAMING ",JSON.stringify({"status":report.status,"errors":errors}));await game.quit_game(0 if errors.is_empty() else 2)
