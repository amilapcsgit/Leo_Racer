extends SceneTree
## Native complete-cabin captures and actual compiled-geometry export.
const Profile = preload("res://scripts/catalog/cockpit_profile279.gd")
var game: Node3D
var output := ""
var errors: Array[String] = []
var checks := 0
var measurements: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: errors.append(label);push_error(label)
func settle() -> void:
	for frame in 8: await process_frame
func capture(label: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))
func encode(point: Vector3) -> Array: return [point.x, point.y, point.z]
func changed_pixels(before: Image, after: Image, region: Rect2i) -> int:
	var changed:=0
	for x in range(region.position.x,region.end.x):
		for y in range(region.position.y,region.end.y):
			var a:=before.get_pixel(x,y);var b:=after.get_pixel(x,y)
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>.15:changed+=1
	return changed

func fixed_rotating_diagnostic(kart: LeoKart, pivot: LeoCockpitSteering, id: String, eye: Transform3D) -> void:
	var cyan:=StandardMaterial3D.new();cyan.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;cyan.albedo_color=Color("27f3ed")
	var magenta:=StandardMaterial3D.new();magenta.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;magenta.albedo_color=Color(.85,.03,.34,.75);magenta.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	var restored: Array[Dictionary]=[]
	var region:=AABB(pivot.position-Vector3(.32,.32,.32),Vector3(.64,.64,.64))
	for node in kart.chassis.find_children("*","MeshInstance3D",true,false):
		if not node.mesh:continue
		var pose: Transform3D=kart.chassis.global_transform.affine_inverse()*node.global_transform
		if pivot.is_ancestor_of(node):
			restored.append({"node":node,"override":node.material_override,"overlay":node.material_overlay});node.material_override=cyan
		elif region.intersects(pose*node.mesh.get_aabb()):
			restored.append({"node":node,"override":node.material_override,"overlay":node.material_overlay});node.material_overlay=magenta
	game.local_players[0].camera.global_transform=eye*Transform3D(Basis(Vector3.RIGHT,deg_to_rad(-22.)),Vector3.ZERO)
	for degrees in [0,90]:
		pivot.apply_angle(deg_to_rad(float(degrees)))
		await capture(id+"-fixed-magenta-rotating-cyan-"+str(degrees))
	for row in restored:row.node.material_override=row.override;row.node.material_overlay=row.overlay
	pivot.apply_angle(0.);game.local_players[0].camera.global_transform=eye

func geometry(body: Node3D, visual: Node3D, slot: int, pivot: LeoCockpitSteering, id: String) -> void:
	var vertices: Array = [];var faces: Array = [];var labels: Array = []
	var wheel_vertices: Array = [];var wheel_faces: Array = []
	var region := AABB(pivot.position - Vector3(.40,.40,.60),Vector3(.80,.80,1.20))
	var driver:=visual.get_node_or_null("Driver")
	for node in visual.find_children("*","MeshInstance3D",true,false):
		if not node.mesh:continue
		if node.layers & LeoCameraViews.DRIVER_BITS[slot]:continue
		if driver and (driver==node or driver.is_ancestor_of(node)):continue
		var rotating := pivot.is_ancestor_of(node)
		if "needle_" in String(node.name):continue
		var pose: Transform3D = body.global_transform.affine_inverse()*node.global_transform
		if not rotating and not region.intersects(pose * node.mesh.get_aabb()):continue
		for surface in node.mesh.get_surface_count():
			var arrays: Array=node.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for index in points.size():indices.append(index)
			for index in range(0,indices.size(),3):
				var triangle := [pose*points[indices[index]],pose*points[indices[index+1]],pose*points[indices[index+2]]]
				var box := AABB(triangle[0],Vector3.ZERO).expand(triangle[1]).expand(triangle[2])
				if not rotating and not region.intersects(box):continue
				var target: Array=wheel_vertices if rotating else vertices
				var offset:=target.size()
				for point in triangle:target.append(encode(point))
				if rotating:wheel_faces.append([offset,offset+1,offset+2])
				else:faces.append([offset,offset+1,offset+2]);labels.append(String(node.name))
	var payload := {"id":id,"hub":encode(pivot.position),"axis":encode(pivot.shaft),"vertices":vertices,"faces":faces,"labels":labels,"wheel_vertices":wheel_vertices,"wheel_faces":wheel_faces,"normalization_scale":body.basis.get_scale().x,"normalization_basis":[encode(body.basis.x),encode(body.basis.y),encode(body.basis.z)]}
	FileAccess.open(output.path_join("geometry-"+id+".json"),FileAccess.WRITE).store_string(JSON.stringify(payload))

func run() -> void:
	output=ProjectSettings.globalize_path("res://build/qa279/cockpit")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="):output=argument.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output)
	var asset_root := OS.get_environment("LEO_ASSET_ROOT")
	if asset_root.is_empty():asset_root=ProjectSettings.globalize_path("res://build/content-baseline/GameAssets") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("GameAssets")
	check(LeoAssets.configure(asset_root)==OK and LeoAssets.mount_packs()==OK,"Original content mounts")
	for id in ["bigster","duster","duster_2024"]:
		if OS.has_feature("editor"):
			check(ProjectSettings.load_resource_pack("res://content/ultra/cockpit279-"+id+".pck",false),"Additive cockpit pack mounts / "+id)
		else:
			check(ResourceLoader.exists("res://cockpit279/"+id+"/model.scn"),"Installed additive cockpit pack mounts / "+id)
	LeoVehicleLibrary.discover()
	if "--geometry-only" in OS.get_cmdline_user_args():
		var world:=Node3D.new();root.add_child(world)
		var catalog:=GarageCatalog.shared()
		for id in ["bigster","duster","duster_2024"]:
			var car:=VehicleAssembler.assemble(catalog.vehicle(StringName(id)),catalog.drivers[0]);world.add_child(car)
			var pivot:=car.find_child("CockpitSteering",true,false) as LeoCockpitSteering
			check(pivot!=null,"Compiled cockpit wheel binding / "+id)
			if pivot:pivot.set_process(false);geometry(car.get_node("Chassis"),car,0,pivot,id)
			car.free()
		print("COCKPIT279_GEOMETRY_EXPORTED ",checks," checks / ",errors)
		quit(0 if errors.is_empty() else 1);return
	game=load("res://scenes/main.tscn").instantiate();game.diagnostics_mode=true;root.add_child(game);await game.initialization_finished
	root.size=Vector2i(1280,720)
	for id in ["bigster","duster","duster_2024"]:
		print("COCKPIT279_STAGE ",id)
		game.return_menu();game.set_process(true);game.human_count=1;game.selected_kart=game.catalog.vehicle_index(StringName(id));game.local_players[0].vehicle_id=StringName(id)
		game.set_race_variant("dusk_night")
		await game.start_race();game.set_process(false);game.state="race";game.race_time=2.
		for kart in game.karts:kart.set_physics_process(false)
		var kart: LeoKart=game.player
		kart.active=true
		var pivot:=kart.visual.find_child("CockpitSteering",true,false) as LeoCockpitSteering
		var systems:=kart.visual.get_node_or_null("LiveCockpit") as LeoCockpitSystems
		check(pivot!=null,"One reviewed rigid wheel / "+id)
		check(systems!=null,"Live cockpit installed / "+id)
		if not pivot or not systems:continue
		pivot.set_process(false);systems.set_process(false)
		var profile: Dictionary=Profile.for_vehicle(id)
		check(pivot.get_child_count()==profile.wheel_nodes.size(),"All and only authored wheel meshes rotate / "+id)
		check(systems.screens.size()==2 and systems.mirrors.size()==3,"Instrument/navigation/two side and rear views / "+id)
		kart.steer=1.
		for step in 30:pivot._process(1./60.)
		check(pivot.angle<-.9*pivot.maximum_angle,"Steering input turns the complete wheel in the driving direction / "+id)
		kart.steer=0.
		for step in 60:pivot._process(1./60.)
		check(absf(pivot.angle)<.001,"Wheel returns to its model-specific neutral / "+id)
		game.local_players[0].camera_view="cockpit";game.update_local_camera(game.local_players[0],1.)
		check(absf((kart.global_transform.affine_inverse()*game.local_players[0].camera.global_position).x)>.25,"Camera at authored LHD driver seat / "+id)
		pivot.apply_angle(0.);systems._process(.12)
		await capture(id+"-driver-eye")
		var cluster_zero: Image=systems.screens[0].view.get_texture().get_image()
		cluster_zero.save_png(output.path_join(id+"-cluster-000.png"))
		geometry(kart.chassis,kart.visual,kart.local_slot,pivot,id)
		# A downward head-look shows the entire wheel, fixed shroud and dashboard
		# together. No surrounding meshes are hidden for the sweep evidence.
		var eye: Transform3D=game.local_players[0].camera.global_transform
		for angle in [-135,-90,-45,0,45,90,135]:
			pivot.apply_angle(deg_to_rad(float(angle)))
			game.local_players[0].camera.global_transform=eye*Transform3D(Basis(Vector3.RIGHT,deg_to_rad(-22.)),Vector3.ZERO)
			await capture(id+"-sweep-"+str(angle))
		pivot.apply_angle(0.);game.local_players[0].camera.global_transform=eye
		if "--sweep-video" in OS.get_cmdline_user_args():
			var frames:=output.path_join(id+"-sweep-frames")
			DirAccess.make_dir_recursive_absolute(frames)
			game.local_players[0].camera.global_transform=eye*Transform3D(Basis(Vector3.RIGHT,deg_to_rad(-12.)),Vector3.ZERO)
			for frame in 120:
				pivot.apply_angle(deg_to_rad(135.)*sin(TAU*float(frame)/120.))
				await process_frame;await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(frames.path_join("frame-%04d.png"%frame))
			pivot.apply_angle(0.);game.local_players[0].camera.global_transform=eye
		await fixed_rotating_diagnostic(kart,pivot,id,eye)
		game.race_environment.displayed=1.;game.race_environment.apply(true);systems._process(.12)
		await capture(id+"-night-driver-eye")
		game.race_environment.displayed=0.;game.race_environment.apply(true)
		var row := {"eye":encode(eye.origin),"wheel_hub":encode(pivot.position),"wheel_children":pivot.get_child_count(),"screens":systems.screens.size(),"mirrors":systems.mirrors.size(),"needles":systems.needles.size()}
		if id=="duster":
			check(systems.needles.size()==2,"Original 2014 speed/RPM needles remain independent")
			kart.wheel_motion_speed=0.;kart.motor_audio.rpm=900.;systems.update_needles()
			var zero: Transform3D=systems.needles[0].node.transform
			kart.wheel_motion_speed=120./3.6;kart.motor_audio.rpm=4000.;systems._process(.12)
			check(not systems.needles[0].node.transform.is_equal_approx(zero),"2014 speed needle responds to actual telemetry")
			await capture("duster-live-120kmh")
			row.needle_zero_basis=str(zero.basis);row.needle_120_basis=str(systems.needles[0].node.basis)
		else:
			kart.wheel_motion_speed=120./3.6;kart.motor_audio.rpm=4000.;systems._process(.12)
			await capture(id+"-live-120kmh")
		var cluster_120: Image=systems.screens[0].view.get_texture().get_image()
		cluster_120.save_png(output.path_join(id+"-cluster-120.png"))
		var speed_region:=Rect2i(190,28,190,80) if id!="duster" else Rect2i(20,20,400,100)
		var actual_changed:=changed_pixels(cluster_zero,cluster_120,speed_region)
		check(actual_changed>50,"Rendered in-car speed pixels change from000 to120 / "+id)
		row.speed_pixels_changed=actual_changed
		measurements[id]=row
	var report := {"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"measurements":measurements,"geometry_clearance":"Run validate_cockpit_clearance279.py on exported compiled meshes"}
	FileAccess.open(output.path_join("functional.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("COCKPIT279_RESULT ",JSON.stringify(report))
	await game.quit_game(0 if errors.is_empty() else 1)
