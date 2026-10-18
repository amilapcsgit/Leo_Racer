extends SceneTree
## Isolated art QA, independent of game state and player controller.

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("79bceb")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b7d9f4")
	settings.ambient_light_energy = .62
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.tonemap_exposure = 1.0
	settings.glow_enabled = true
	settings.ssao_enabled = true
	env.environment = settings
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-45,0)
	sun.light_color = Color("ffe2b0")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180
	world.add_child(sun)
	world.add_child(load("res://assets/models/lotus_coast.glb").instantiate())
	var tower: Node3D = load("res://assets/models/lotus_tower.glb").instantiate()
	tower.position = Vector3(0,0,-230)
	world.add_child(tower)
	var circuit := LeoCircuit.new()
	var city := LeoCity.new()
	world.add_child(city)
	city.setup(circuit)
	var camera := Camera3D.new()
	camera.fov = 65
	camera.far = 900
	world.add_child(camera)
	camera.current = true
	DirAccess.make_dir_recursive_absolute("res://docs/city-review")
	for s in [10.0, 250.0, 500.0, 650.0]:
		camera.position = circuit.sample(s) + Vector3.UP * 4.2 - circuit.direction(s) * 8
		camera.look_at(circuit.sample(s+30) + Vector3.UP * 3.0)
		await create_timer(.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/city-review/street_%d.png" % int(s))
	camera.position = Vector3(-210,170,210)
	camera.look_at(Vector3(15,8,-25))
	await create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/city-review/overview.png")
	print("CITY_VISUAL_COMPLETE")
	quit()
