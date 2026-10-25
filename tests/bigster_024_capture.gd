extends SceneTree
var out := OS.get_environment("BIGSTER_QA_ROOT") if OS.has_environment("BIGSTER_QA_ROOT") else ProjectSettings.globalize_path("res://../../Bigster/leo_racer_024")
func _initialize() -> void: run.call_deferred()
func shot(view: SubViewport, path: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(path)
func run() -> void:
	LeoAssets.configure(OS.get_environment("LEO_ASSET_ROOT") if OS.has_environment("LEO_ASSET_ROOT") else ProjectSettings.globalize_path("res://build/CustomCars-delivery/LeoRacer/GameAssets"))
	LeoAssets.mount_packs()
	LeoVehicleLibrary.discover(out.path_join("stage/vehicles"))
	var catalog := GarageCatalog.shared();var v := catalog.vehicle(&"bigster")
	await LeoAssets.scene_async(v.model_path,self)
	var view := SubViewport.new();view.size=Vector2i(1280,800);view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view.msaa_3d=Viewport.MSAA_4X;root.add_child(view)
	var world := Node3D.new();view.add_child(world)
	var env := WorldEnvironment.new();var e := Environment.new();env.environment=e
	e.background_mode=Environment.BG_COLOR;e.background_color=Color(.12,.16,.2)
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color(.78,.85,1.);e.ambient_light_energy=.7
	e.background_mode=Environment.BG_SKY
	var sky:=Sky.new();var sky_mat:=ProceduralSkyMaterial.new();sky_mat.sky_top_color=Color(.18,.3,.5);sky_mat.sky_horizon_color=Color(.85,.9,1.);sky_mat.ground_horizon_color=Color(.6,.65,.7);sky_mat.ground_bottom_color=Color(.08,.1,.13);sky.sky_material=sky_mat;e.sky=sky
	e.tonemap_mode=Environment.TONE_MAPPER_FILMIC;world.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-35,0);sun.light_energy=2.;sun.shadow_enabled=true;world.add_child(sun)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-20,140,0);fill.light_energy=.7;world.add_child(fill)
	var floor:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(200,200);floor.mesh=plane
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.16,.18,.2);mat.roughness=.4;floor.material_override=mat;world.add_child(floor)
	var camera:=Camera3D.new();camera.fov=38.;world.add_child(camera);camera.current=true
	var car:=VehicleAssembler.assemble(v,catalog.driver(&"human"));world.add_child(car)
	camera.position=Vector3(-7.,3.8,-9.);camera.look_at(Vector3(0,1.,0));await shot(view,out.path_join("front_godot.png"))
	var thumb:=view.get_texture().get_image();thumb.resize(640,400,Image.INTERPOLATE_LANCZOS);thumb.save_png(out.path_join("stage/vehicles/bigster/thumbnail.png"))
	camera.position=Vector3(7.,3.4,9.);camera.look_at(Vector3(0,1.,0));await shot(view,out.path_join("rear_godot.png"))
	e.ambient_light_energy=.1;sun.light_energy=.04;fill.light_energy=.04;e.background_color=Color(.008,.012,.018)
	camera.position=Vector3(-6.,3.4,-9.);camera.look_at(Vector3(0,.6,-1.));await shot(view,out.path_join("headlights_godot.png"))
	camera.position=Vector3(6.,3.,8.);camera.look_at(Vector3(0,.8,.7));car.get_node("Chassis/VehicleLighting").update_state(true);await shot(view,out.path_join("brakes_godot.png"))
	e.ambient_light_energy=.7;sun.light_energy=2.;fill.light_energy=.7;e.background_color=Color(.12,.16,.2)
	car.free()
	for driver in catalog.drivers:
		car=VehicleAssembler.assemble(v,driver);world.add_child(car)
		camera.position=Vector3(-3.,2.2,-3.5);camera.fov=32.;camera.look_at(Vector3(-.4,1.45,-.1))
		await shot(view,out.path_join("driver_"+String(driver.id)+".png"));car.free()
	print("BIGSTER_024_CAPTURE_OK");quit()
