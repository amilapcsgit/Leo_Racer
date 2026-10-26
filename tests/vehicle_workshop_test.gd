extends SceneTree
var errors: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i.ZERO
	var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	var original_roster_size: int=game.catalog.vehicles.size()
	var editor:=LeoVehicleSetup.new();editor.game=game;editor.configure(game.catalog.vehicle(&"bigster"));root.add_child(editor)
	var deadline:=Time.get_ticks_msec()+30000
	while not is_instance_valid(editor.preview) and Time.get_ticks_msec()<deadline:await process_frame
	check(is_instance_valid(editor.preview),"Workshop preview loads")
	if not is_instance_valid(editor.preview):quit(1);return
	check(editor.validation().is_empty(),"Original wheel groups and fits validate")
	check(editor.preview.wheel_spin_pivots.size()==4,"All four pivot assemblies preview")
	var original_scale: Vector3=editor.preview.chassis.transform.basis.get_scale()
	check(original_scale.is_equal_approx(Vector3.ONE*1.3),"Bigster scale applied once")
	editor.spin=true;editor.steering=true
	for i in 5:await process_frame
	check(editor.preview.wheel_spin_pivots[0].basis!=Basis.IDENTITY,"Spin preview updates wheel rotation")
	for driver in game.catalog.drivers:
		editor.driver_id=String(driver.id);await editor.refresh_preview()
		check(editor.preview.visual.get_node("Driver").get_meta("visible_driver_id")==driver.id,"Driver preview: "+String(driver.id))
	editor.data.id="workshop_test_vehicle";editor.data.display_name="Workshop Test Vehicle";editor.data.max_speed=20.;editor.build_fields()
	await editor.save_vehicle();check(editor.status.text.contains("Private Test Drive"),"Test drive required before save")
	editor.test_drive();await physics_frame
	check(is_instance_valid(editor.trial) and editor.trial.definition.max_speed==20.,"Private drive uses unsaved tuning")
	check(game.catalog.vehicles.size()==original_roster_size and game.state=="menu","Private viewport never changes race roster or session")
	editor.trial_input.inject_test("accelerate",1.)
	for i in 100:await physics_frame
	check(editor.trial.speed>10 and editor.trial.position.is_finite(),"Private drive uses actual arcade physics")
	editor.end_trial();check(editor.tested,"Private drive confirmation recorded")
	await editor.save_vehicle()
	check(not editor.saved_folder.is_empty(),"Portable folder saved")
	var folder:=editor.saved_folder
	if not folder.is_empty():
		for name in ["model.glb","vehicle.json","thumbnail.png","LICENSE.txt"]:check(FileAccess.file_exists(folder.path_join(name)),"Saved "+name)
		await game.refresh_content();check(game.catalog.vehicle(&"workshop_test_vehicle")!=null and not game.catalog.vehicle(&"workshop_test_vehicle").official,"Unchanged game discovers new mod vehicle")
		for name in ["model.glb","vehicle.json","thumbnail.png","LICENSE.txt"]:DirAccess.remove_absolute(folder.path_join(name))
		DirAccess.remove_absolute(folder);await game.refresh_content()
	if DisplayServer.get_name()!="headless":
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/modularity/workshop.png")
	editor.queue_free();game.stop_all_audio();game.queue_free();await process_frame;await process_frame
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"source_models_untouched":true,"private_test_uses_game_physics":true}
	FileAccess.open("res://build/modularity/workshop.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("WORKSHOP_TEST ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
