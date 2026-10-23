extends SceneTree
## Repeatable presentation tour. Uses -- --drive-test to avoid personal settings.
## Physical simulation is frozen only for framing; no gameplay source is modified.
var game: Node3D
var destination := "res://docs/qa-astra/captures"
var captures: Array[Dictionary] = []
var errors: Array[String] = []
var previous_captures: Array = []

func _initialize() -> void:
	run.call_deferred()

func capture(label: String, wait: float = .42) -> void:
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var output := destination.path_join(label+".png")
	var saved := image.save_png(output)
	if saved!=OK: errors.append("Could not save "+label)
	var hud_state := {"mode":game.hud.scene_mode,"reduced_motion":game.reduced_motion,"photo_mode":game.hud.photo_mode}
	for key in ["countdown","speed","nitro","callout"]:
		if game.hud.labels.has(key) and is_instance_valid(game.hud.labels[key]):hud_state[key]=game.hud.labels[key].text
	captures.append({"name":label,"width":image.get_width(),"height":image.get_height(),"camera_position":str(game.camera.position),"camera_rotation":str(game.camera.rotation_degrees),"selected_driver":game.selected_driver,"selected_vehicle":game.selected_kart,"hud":hud_state})
	print("ASTRA_CAPTURE ",label," ",image.get_size())

func frame_track(fraction: float, distance: float = 7.2, height: float = 3.15) -> void:
	var s: float = game.circuit.length*fraction
	game.player.place(s,0)
	game.player.reset_physics_interpolation()
	var direction: Vector3 = game.circuit.direction(s)
	game.camera.position = game.player.position-direction*distance+Vector3.UP*(height+game.player.camera_height_offset)
	game.camera.look_at(game.player.position+direction*7+Vector3.UP*1.75)
	game.camera.fov = 66

func frame_art(node: MeshInstance3D, distance: float) -> void:
	var front: Vector3 = node.global_basis.z.normalized()
	game.camera.global_position = node.global_position+front*distance+Vector3.UP*.3
	game.camera.look_at(node.global_position)
	game.camera.fov = 58

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	var old_manifest := destination.path_join("capture-manifest.json")
	if FileAccess.file_exists(old_manifest):
		var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(old_manifest))
		if previous is Dictionary: previous_captures = previous.get("captures",[])
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game);await game.initialization_finished
	await process_frame
	# Freeze the menu/garage camera and showroom rotation for matching images.
	game.set_process(false)
	await capture("01-menu",1.0)
	game.hud.show_guide()
	await capture("02-guide")
	game.hud.clear(game.hud.modal_root)
	game.hud.show_settings()
	await capture("03-settings")
	game.hud.clear(game.hud.modal_root)
	game.selected_driver = 4
	for i in game.KARTS.size():
		game.selected_kart = i
		game.hud.show_garage()
		await capture("garage-%02d-%s"%[i+1,String(game.KARTS[i].color)],.5)
	game.selected_kart = 4
	await game.start_race()
	for kart in game.karts: kart.set_physics_process(false)
	frame_track(.002)
	await capture("04-countdown")
	game.state = "capture"
	game.race_time = 54.447
	for pair in [["05-coast",.045],["06-harbor",.415],["07-lagoon",.55],["08-gardens",.755],["09-fort",.91]]:
		frame_track(float(pair[1]))
		await capture(pair[0])
	# A broad view proves the expanded circuit, water and raised island ground.
	game.hud.photo_mode = true
	game.hud.hud_root.hide()
	game.camera.position = Vector3(-270,365,305)
	game.camera.look_at(Vector3(70,0,-70))
	game.camera.fov = 66
	await capture("10-route-overview",.8)
	var boards := get_nodes_in_group("sri_advertising")
	var portrait: MeshInstance3D
	var wide: MeshInstance3D
	for item in boards:
		var mesh := item.mesh as QuadMesh
		if mesh and mesh.size.x>mesh.size.y and not is_instance_valid(wide): wide=item
		if mesh and mesh.size.y>mesh.size.x and not is_instance_valid(portrait): portrait=item
	if is_instance_valid(wide):
		frame_art(wide,7)
		await capture("11-billboard-wide")
		for other in boards:
			if other!=wide and other.get_parent()==wide.get_parent() and other.global_basis.z.dot(wide.global_basis.z)<-.8:
				frame_art(other,7)
				await capture("11b-billboard-wide-reverse")
				break
	if is_instance_valid(portrait):
		frame_art(portrait,4.3)
		await capture("12-billboard-portrait")
		for other in boards:
			if other!=portrait and other.get_parent()==portrait.get_parent() and other.global_basis.z.dot(portrait.global_basis.z)<-.8:
				frame_art(other,4.3)
				await capture("12b-billboard-portrait-reverse")
				break
	var flags := get_nodes_in_group("sri_national_flag")
	if not flags.is_empty():
		frame_art(flags[mini(6,flags.size()-1)],5)
		await capture("13-national-flag")
	var decal_index := 0
	for decal in get_nodes_in_group("astra_road_decal"):
		game.camera.global_position = decal.global_position+decal.global_basis.z*7+Vector3.UP*8
		game.camera.look_at(decal.global_position)
		game.camera.fov = 56
		decal_index += 1
		await capture("14-road-decal-%02d"%decal_index,.25)
	game.hud.photo_mode = false
	game.hud.hud_root.show()
	frame_track(.045)
	game.player.active = true
	game.player.speed = 40
	game.player.wheel_motion_speed = 40
	game.player.boost(2,"NITRO BOOST")
	await capture("15-nitro",.8)
	game.set_reduced_motion(true)
	await capture("15b-nitro-reduced-motion")
	game.set_reduced_motion(false)
	game.player.boost_time = 0
	game.player.wheel_motion_speed = 49
	await capture("16-speed-lines")
	game.player.speed = 29
	game.player.wheel_motion_speed = 29
	game.player.drifting = true
	game.player.drift_charge = 1.6
	game.player.steer = .6
	game.player.visual.rotation.y = -.25
	for i in range(30):
		game.player.global_position -= game.player.global_basis.z*.10
		await process_frame
	await capture("17-drift")
	game.player.drifting = false
	game.player.boost_time = 0
	game.player.speed = 0
	game.player.wheel_motion_speed = 0
	game.state = "race"
	game.toggle_pause()
	await capture("18-pause")
	game.toggle_pause()
	game.state = "results"
	for i in game.karts.size():
		game.karts[i].finished = true
		game.karts[i].finish_time = 176.321+i*2.175
	game.best_time = 176.321
	game.best_lap = 56.553
	game.hud.show_results()
	await capture("19-results")
	for vehicle in [7,8]:
		game.selected_kart = vehicle
		await game.start_race()
		game.state = "capture"
		game.race_time = 54.447
		for kart in game.karts: kart.set_physics_process(false)
		frame_track(.045)
		await capture("20-race-%s"%game.KARTS[vehicle].color)
	# Remove only obsolete PNGs explicitly recorded by this tool's prior manifest.
	var current_names: Array[String] = []
	for item in captures:current_names.append(item.name)
	for item in previous_captures:
		var old_name: String = item.get("name","")
		if old_name.is_empty() or old_name in current_names or old_name.get_file()!=old_name:continue
		var old_file := ProjectSettings.globalize_path(destination.path_join(old_name+".png"))
		if FileAccess.file_exists(old_file):DirAccess.remove_absolute(old_file)
	var file := FileAccess.open(destination.path_join("capture-manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS" if errors.is_empty() else "FAIL","captures":captures,"errors":errors,"presentation_states_are_staged":true,"renderer":RenderingServer.get_current_rendering_method(),"godot_version":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name()},"  "))
	file.close()
	game.stop_all_audio()
	game.queue_free()
	await process_frame
	await process_frame
	print("ASTRA_CAPTURE_REPORT ",JSON.stringify({"captures":captures.size(),"errors":errors}))
	quit(0 if errors.is_empty() else 1)
