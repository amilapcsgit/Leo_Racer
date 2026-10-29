extends SceneTree
var game: Node3D
var output: String
var errors: Array[String]=[]
var checks:=0
var rows: Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:errors.append(text);push_error(text)
func screenshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	output=ProjectSettings.globalize_path("res://build/qa270/previews")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="):output=argument.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1600,900);DisplayServer.window_set_size(root.size);Engine.max_fps=60
	var content:=ProjectSettings.globalize_path("res://build/content-baseline/GameAssets") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("GameAssets")
	check(LeoAssets.configure(content)==OK and LeoAssets.mount_packs()==OK,"Content mounts")
	LeoVehicleLibrary.discover();game=load("res://scenes/main.tscn").instantiate();game.diagnostics_mode=true;root.add_child(game);await game.initialization_finished
	game.set_reduced_motion(true);game.hud.show_garage("home")
	var selector: ModularCarSelector=game.hud.garage_selector
	for index in game.catalog.vehicles.size():
		var car: VehicleDefinition=game.catalog.vehicles[index]
		await selector.set_selection(&"human",car.id);selector.reset_view()
		check(selector.assembly.get_meta("vehicle_id")==car.id,"Model identity / "+String(car.id))
		var image:=await LeoPreviewArt.capture_model(selector.showroom,selector.viewport,self)
		var expected:=LeoPreviewArt.texture(car,true).get_image()
		var actual_bounds:=image.get_used_rect();var expected_bounds:=expected.get_used_rect()
		var delta:=maxf(Vector2(actual_bounds.position).distance_to(Vector2(expected_bounds.position)),Vector2(actual_bounds.end).distance_to(Vector2(expected_bounds.end)))
		check(image.get_size()==Vector2i(1600,900) and expected.get_size()==image.get_size(),"Full-canvas camera framing / "+String(car.id))
		check(image.get_pixel(0,0).a==0. and expected.get_pixel(0,0).a==0.,"Transparent backdrop / "+String(car.id))
		check(delta<=2.,"Live-render silhouette matches placeholder / "+String(car.id))
		image.save_png(output.path_join("car-%02d.png" % index))
		rows.append({"id":String(car.id),"silhouette_error_pixels":delta,"actual_bounds":str(actual_bounds),"png_bounds":str(expected_bounds)})
		print("ULTRA_PREVIEW_MATCH ",car.id," ",delta)
	await selector.scheduler.pause_for_race();selector.assembly=null
	selector.set_reduced_motion(false);selector.choose_vehicle(&"bigster");selector.scheduler.suspended=true
	await process_frame
	check(selector.loading_preview.visible and selector.loading_preview.modulate.a==1. and selector.race_button.disabled,"Opaque PNG covers pending 3D preparation")
	check(not selector.back_button.disabled and not selector.next_button.disabled,"Navigation stays responsive during load")
	await screenshot("placeholder")
	selector.scheduler.suspended=false;await selector.preview_ready
	selector.preview_fade.pause();selector.preview_fade.custom_step(.09)
	check(selector.loading_preview.modulate.a>.35 and selector.loading_preview.modulate.a<.65,"180 ms dissolve has a half-opacity midpoint")
	await screenshot("dissolve-midpoint")
	selector.preview_fade.play();await selector.preview_fade.finished
	check(not selector.loading_preview.visible,"PNG releases after live handoff")
	await screenshot("loaded")
	for id in [&"duster",&"bigster",&"duster_2024"]:
		selector.choose_vehicle(id)
		check(selector.loading_preview.texture.resource_path.ends_with(String(id)+"-hero.png"),"Rapid navigation shows the selected PNG / "+String(id))
	await selector.set_selection(&"human",&"duster_2024")
	check(selector.assembly.get_meta("vehicle_id")==&"duster_2024","Stale requests cannot replace the latest car")
	check(LeoPreviewStream.entries.size()<=3 and selector.scheduler.prepared.size()<=3,"Three-entry caches remain bounded")
	var missing:=game.catalog.vehicles[0].duplicate() as VehicleDefinition;missing.id=&"missing-art-fixture"
	check(LeoPreviewArt.texture(missing,true).resource_path.ends_with("/custom-car.png"),"Missing artwork has a transparent custom-car fallback")
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"rows":rows,"renderer":RenderingServer.get_current_rendering_method()}
	FileAccess.open(output.path_join("previews.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ULTRA_PREVIEW_TEST ",JSON.stringify(report));await game.quit_game(0 if errors.is_empty() else 1)
