extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(640,480)
	var world:=Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("b4c9d1")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.65
	world.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-35,0);sun.light_energy=1.1;world.add_child(sun)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;world.add_child(camera);camera.current=true
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/colombo_city/modules.json"))
	DirAccess.make_dir_recursive_absolute("res://build/colombo-visuals/modules")
	for entry in data.modules:
		var model:Node3D=load(entry.path).instantiate();world.add_child(model)
		var span:float=maxf(entry.width,maxf(entry.height,entry.depth))
		camera.size=span*1.55
		camera.position=Vector3(span*.8,entry.height*.5+span*.6,span*1.8)
		camera.look_at(Vector3(0,entry.height*.5,0))
		await create_timer(.03).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/colombo-visuals/modules/"+entry.id+".png")
		model.free()
	world.free();await process_frame;print("MODULE_CAPTURE_COMPLETE");quit()
