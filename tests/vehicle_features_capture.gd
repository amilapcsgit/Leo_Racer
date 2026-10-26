extends SceneTree
var out := ""
func _initialize() -> void:run.call_deferred()
func shot(name: String) -> void:
	for i in 6:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name+".png"))
func run() -> void:
	out=OS.get_environment("VEHICLE_QA_OUTPUT")
	if out.is_empty():out=ProjectSettings.globalize_path("res://docs/qa-vehicle232/"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(out)
	var assets:=OS.get_environment("LEO_ASSET_ROOT")
	if assets.is_empty():assets=ProjectSettings.globalize_path("res://build/Release-2.3.2/GameAssets")
	LeoAssets.configure(assets);LeoAssets.mount_packs();LeoVehicleLibrary.discover(assets.path_join("vehicles"))
	var vehicle:=GarageCatalog.shared().vehicle(&"bigster");await LeoAssets.scene_async(vehicle.model_path,self)
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i.ZERO
	DisplayServer.window_set_size(root.size)
	var world:=Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	var e:=environment.environment;e.background_mode=Environment.BG_COLOR;e.background_color=Color("708fa8");e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("c4d9ed");e.ambient_light_energy=.65;e.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	world.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-50,-35,0);sun.light_energy=1.5;sun.shadow_enabled=true;world.add_child(sun)
	var floor:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(100,100);floor.mesh=plane
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("29303b");mat.roughness=.55;floor.material_override=mat;world.add_child(floor)
	var a:=VehicleAssembler.assemble(vehicle,GarageCatalog.shared().driver(&"human"));world.add_child(a);a.position.x=-1.6
	var b:=VehicleAssembler.assemble(vehicle,GarageCatalog.shared().driver(&"human"));world.add_child(b);b.position.x=1.6
	var rig: LeoVehicleFeatures=a.get_node("Chassis/VehicleLighting")
	var other: LeoVehicleFeatures=b.get_node("Chassis/VehicleLighting")
	var camera:=Camera3D.new();camera.fov=40;world.add_child(camera);camera.make_current()
	camera.position=Vector3(8,4.4,12);camera.look_at(Vector3(0,1.1,0))
	await shot("rear-running-lamps")
	rig.update_state(true,false);await shot("rear-braking-left-only")
	rig.update_state(false,true);await shot("rear-reversing-left-only")
	rig.update_state(false,false);rig.trigger(1)
	for i in 2:rig._process(1.)
	camera.position=Vector3(-6,7,7);camera.look_at(Vector3(0,1.,0));await shot("sunroof-open-left-closed-right")
	e.ambient_light_energy=.08;sun.light_energy=.05;e.background_color=Color("111d2c")
	camera.position=Vector3(7,3.5,-12);camera.look_at(Vector3(0,.8,-1.))
	rig.toggle_headlights();await shot("headlights-off-left-on-right")
	rig.toggle_headlights();await shot("headlights-both-on")
	# Close evidence makes the physical optical groups assessable, rather than
	# accepting a distant screenshot or controller state as proof of correct lamps.
	b.visible=false;a.position=Vector3.ZERO
	e.ambient_light_energy=.18;sun.light_energy=.12
	camera.fov=32;camera.position=Vector3(3.4,2.1,7.8);camera.look_at(Vector3(0,1.1,2.))
	rig.update_state(false,false);await shot("close-rear-y-running")
	rig.update_state(true,false);await shot("close-rear-y-braking")
	rig.update_state(false,true);await shot("close-rear-bumper-reverse")
	camera.position=Vector3(-.75,1.48,4.6);camera.look_at(Vector3(-.83,1.43,2.82));await shot("close-y-optical-detail")
	rig.update_state(false,false);rig.toggle_headlights()
	camera.position=Vector3(3.4,2.1,7.8);camera.look_at(Vector3(0,1.1,2.));await shot("close-rear-off")
	rig.toggle_headlights()
	camera.position=Vector3(3.4,2.1,-7.8);camera.look_at(Vector3(0,1.1,-2.));await shot("close-front-main-and-signature")
	rig.toggle_headlights();await shot("close-front-off")
	FileAccess.open(out.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"diagnostics":Array(rig.diagnostics)+Array(other.diagnostics),"images":13},"  "))
	print("VEHICLE_FEATURE_CAPTURE ",out)
	a.free();b.free();world.free();await process_frame;quit()
