extends SceneTree
var game: Node3D
var output:="res://build/qa-lighting/presentation"
var checks:=0
var errors: Array[String]=[]
var frames: Array[float]=[]
var sampling:=false
func _initialize() -> void:run.call_deferred()
func _process(dt: float) -> bool:
	if sampling:frames.append(dt*1000.)
	return false
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	var previous:=sampling;sampling=false
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
	await process_frame;await process_frame;sampling=previous
func wait_cache(scheduler: LeoPreviewScheduler) -> void:
	var until:=Time.get_ticks_msec()+20000
	while scheduler.prepared.size()<mini(3,game.catalog.vehicles.size()) and Time.get_ticks_msec()<until:await process_frame
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1920,1080);DisplayServer.window_set_size(root.size);Engine.max_fps=120
	check(LeoAssets.configure(ProjectSettings.globalize_path("res://build/lighting-content/GameAssets"))==OK and LeoAssets.mount_packs()==OK,"Content mounts")
	LeoVehicleLibrary.discover()
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	game.diagnostics_mode=true
	var selector: ModularCarSelector=game.hud.garage_selector
	await wait_cache(selector.scheduler)
	check(selector.scheduler.prepared.size()==3,"Selected and both neighbors assemble while Home is visible")
	await capture("home")
	var began:=Time.get_ticks_usec();game.hud.show_garage("home");var ui_ms:=(Time.get_ticks_usec()-began)/1000.
	sampling=true
	await selector.set_selection(selector.driver_id,selector.vehicle_id)
	var warm_ms:=(Time.get_ticks_usec()-began)/1000.
	check(selector.vehicle_cards.size()==21,"Carousel contains all 21 cars")
	check(game.catalog.vehicles.all(func(vehicle):return vehicle.thumbnail.resource_path.begins_with("res://assets/ui/art/garage-cars/")),"All cards use consistent showroom thumbnails")
	check(is_instance_valid(selector.assembly),"Prepared selected car appears")
	check(selector.carousel.compact and selector.carousel.cards.filter(func(card):return card.visible).size()==6,"All six drivers use compact portraits")
	check(selector.showroom.get_node_or_null("VehicleDisplayPlatform")!=null and selector.showroom.get_node_or_null("ColomboBackdropScreen")!=null,"Platform and Colombo screen are real showroom geometry")
	var preview_driver:=selector.assembly.get_node_or_null("Driver") as Node3D
	check(not preview_driver or not preview_driver.visible,"Showroom car has no 3D driver")
	await capture("garage")
	var switches: Array=[]
	for direction in [1,-1]:
		await wait_cache(selector.scheduler)
		var id: StringName=game.catalog.vehicles[posmod(game.catalog.vehicle_index(selector.vehicle_id)+direction,21)].id
		began=Time.get_ticks_usec();await selector.set_selection(selector.driver_id,id);switches.append((Time.get_ticks_usec()-began)/1000.)
	check(selector.scheduler.prepared.size()<=3,"Prepared instance count stays bounded")
	sampling=false
	await selector.set_selection(selector.driver_id,&"duster")
	var features:=selector.preview_features()
	check(features!=null and selector.preview_actions.size()==3 and not selector.preview_actions[1].disabled and not selector.preview_actions[2].disabled,"Duster exposes lights, doors and trunk controls")
	if features:
		var lights:=features.headlights_on;selector.preview_action(0);check(features.headlights_on!=lights,"Showroom light button toggles actual vehicle lights");selector.preview_action(0)
		for slot in [1,2]:
			selector.preview_action(slot)
			check(features.actions.any(func(action):return int(action.definition.slot)==slot and action.open),"Showroom action opens slot "+str(slot))
		await create_timer(1.4).timeout;await capture("garage-duster-open")
		for slot in [1,2]:selector.preview_action(slot)
		await create_timer(1.4).timeout
		check(features.actions.all(func(action):return not action.open and float(action.progress)<.001),"Showroom actions close completely")
	selector.set_reduced_motion(true);check(selector.showroom_parallax==Vector2.ZERO,"Reduced Motion immediately resets showroom parallax");selector.set_reduced_motion(false)
	var p1_vehicle: StringName=game.local_players[0].vehicle_id
	game.selected_player_slot=1;game.hud.show_garage("lobby")
	selector.choose_vehicle(&"duster_2024");await selector.set_selection(selector.driver_id,&"duster_2024")
	check(game.local_players[0].vehicle_id==p1_vehicle and game.local_players[1].vehicle_id==&"duster_2024","Player 2 garage changes preserve Player 1 ownership")
	game.hud.frontend.show_setup(1);await capture("setup-solo")
	game.hud.frontend.show_setup(2);await capture("setup-split")
	game.human_count=1;game.hud.frontend.show_home()
	for extent in [Vector2i(1280,720),Vector2i(2560,1440),Vector2i(2560,1080),Vector2i(1920,1080)]:
		root.size=extent;DisplayServer.window_set_size(extent);await process_frame;await process_frame
		check(game.hud.scale.x>0.,"Layout adapts to "+str(extent));await capture("home-"+str(extent.x)+"x"+str(extent.y))
		game.hud.show_garage("home");await selector.set_selection(selector.driver_id,selector.vehicle_id);await capture("garage-"+str(extent.x)+"x"+str(extent.y));game.hud.frontend.show_home()
	var report: Dictionary={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"ui_ms":ui_ms,"warm_ms":warm_ms,"neighbor_ms":switches,"worst_ms":frames.max() if not frames.is_empty() else 0.,"largest_preparation_ms":LeoPreparationBudget.largest_slice/1000.,"timings":LeoPreviewStream.timings}
	FileAccess.open(output.path_join("presentation.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	game.queue_free();await process_frame;await process_frame
	print("LIGHTING_PRESENTATION ",JSON.stringify(report));quit(0 if errors.is_empty() else 2)
