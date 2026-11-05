extends SceneTree
var game: Node3D
var checks:=0
var errors: Array[String]=[]
var output: String
var measurements: Dictionary={}
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func settle(frames: int=8) -> void:
	for i in frames:await process_frame
func shot(name: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	output=ProjectSettings.globalize_path("res://build/qa278/release278")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="):output=argument.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output)
	check(LeoAssets.configure(OS.get_environment("LEO_ASSET_ROOT"))==OK and LeoAssets.mount_packs()==OK,"Released assets mount without changes")
	LeoVehicleLibrary.discover()
	game=load("res://scenes/main.tscn").instantiate();game.diagnostics_mode=true;root.add_child(game);await game.initialization_finished
	print("RELEASE278_STAGE settings")
	settings()
	inputs()
	contacts()
	if "--unit-only" in OS.get_cmdline_user_args():
		var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors}
		FileAccess.open(output.path_join("release278-unit.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
		print("RELEASE278_UNIT ",JSON.stringify(report));await game.quit_game(0 if errors.is_empty() else 1);return
	print("RELEASE278_STAGE reference")
	await free_space_reference()
	print("RELEASE278_STAGE settings-captures")
	for extent in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=extent;await settle()
		game.hud.frontend.show_settings();await settle()
		var tabs:=game.hud.modal_root.find_child("SettingsTabs",true,false) as TabContainer
		check(tabs!=null and tabs.get_tab_count()==4,"Four settings tabs / "+str(extent))
		for tab in 4:
			tabs.current_tab=tab;await shot("settings-%dx%d-%s"%[extent.x,extent.y,tabs.get_tab_title(tab)])
		game.hud.frontend.close_modal()
	game.selected_kart=game.catalog.vehicle_index(&"bigster");game.local_players[0].vehicle_id=&"bigster";game.human_count=2;game.local_players[1].vehicle_id=&"duster"
	print("RELEASE278_STAGE cameras")
	await game.start_race();game.state="race";game.set_process(false);game.set_physics_process(false)
	for kart in game.karts:kart.set_physics_process(false);kart.active=true
	check(LeoCameraViews.available(game.player.definition)==["chase","ghost","cockpit"],"Bigster has reviewed cockpit")
	check(LeoCameraViews.available(game.local_players[1].kart.definition)==["chase","ghost"],"Unreviewed interior skips cockpit")
	var first: LeoLocalPlayer=game.local_players[0];var second: LeoLocalPlayer=game.local_players[1]
	second.camera_view="cockpit";game.update_local_camera(second,1./60.)
	check(LeoCameraViews.effective(second)=="chase" and second.camera_view=="cockpit","Unavailable cockpit retains saved preference")
	second.camera_view="chase"
	for view in ["ghost","cockpit"]:
		first.camera_view=view;first.kart.boost_time=0.;first.feedback.play_boost_explicit("drift",1,1.6)
		game.update_local_camera(first,1./60.)
		check(first.feedback.get_boost_gain()==0.,"Cancelled boost feedback clears in "+view)
	for mode in ["chase","ghost","cockpit"]:
		first.camera_view=mode;game.update_local_camera(first,1./60.);game.update_local_camera(second,1./60.)
		check(bool(first.camera.cull_mask & LeoCameraViews.BODY_BITS[0])==(mode!="ghost"),"Own-body visibility / "+mode)
		check(bool(second.camera.cull_mask & LeoCameraViews.BODY_BITS[0]),"Other viewport retains P1 body / "+mode)
		check(bool(first.camera.cull_mask & LeoCameraViews.DRIVER_BITS[0])==(mode=="chase"),"Own driver visibility / "+mode)
		var before: Transform3D=first.camera.global_transform
		game.input_router.players[0].inject_test("look_back",1.);game.update_local_camera(first,1.)
		check(first.camera.global_transform.is_finite(),"Look-back finite / "+mode)
		if mode!="chase":check(before.basis.z.dot(first.camera.global_basis.z)<-.9,"Interior/ghost look-back reverses heading")
		game.input_router.players[0].inject_test("look_back",0.);game.update_local_camera(first,1.)
		await shot("split-"+mode)
	# Route a real root-viewport pointer event through each split container.
	for slot in 2:
		var local: LeoLocalPlayer=game.local_players[slot];local.camera_view="chase"
		var button: Button=game.split_view.overlays[slot].camera_button
		var container: SubViewportContainer=game.split_view.views[slot].get_parent()
		var at: Vector2=container.get_global_transform_with_canvas()*(button.get_global_transform_with_canvas()*(button.size*.5))
		for pressed in [true,false]:
			var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;root.push_input(event,true);await settle(2)
		check(local.camera_view=="ghost","Split-screen Camera View button receives pointer / P"+str(slot+1))
	second.camera_view="chase"
	first.camera_view="chase";game.cycle_camera(0)
	check(first.camera_view=="ghost" and second.camera_view=="chase","Camera cycling is per player")
	var restored:=LeoLocalPlayer.new();restored.restore(first.selection(),game.catalog)
	check(restored.camera_view=="ghost","Camera preference round-trips")
	for reduced in [true,false]:
		game.set_reduced_motion(reduced)
		for mode in ["chase","ghost","cockpit"]:
			first.camera_view=mode;game.update_local_camera(first,1./60.)
			check(first.camera.global_transform.is_finite(),"Camera finite / reduced="+str(reduced)+" / "+mode)
	game.set_reduced_motion(true)
	var kart: LeoKart=first.kart
	kart.speed=30.;kart.steer=.8;kart.suspension_ready=true
	for tick in 90:kart.update_suspension(1./60.,true,-kart.global_basis.z*30.)
	check(absf(kart.suspension_roll)>.005 and absf(kart.suspension_roll)<=deg_to_rad(2.001),"Reduced Motion retains bounded turn lean")
	check(absf(kart.suspension_pitch)<=deg_to_rad(2.001),"Reduced Motion retains bounded pitch")
	game.graphics.motion_blur=true;game.graphics.aa=false;game.graphics.glow=false;game.apply_graphics()
	check(game.split_view.views.all(func(view):return view.msaa_3d==Viewport.MSAA_DISABLED),"AA overrides both viewports")
	check(not game.environment.glow_enabled,"Glow override applies")
	for preset in [1,2,0]:
		game.graphics.upscale=preset;game.graphics.apply()
		check(game.split_view.views.all(func(view):return view.scaling_3d_mode==(Viewport.SCALING_3D_MODE_FSR2 if game.graphics.supported_upscaling() and preset>0 else Viewport.SCALING_3D_MODE_BILINEAR)),"Renderer-aware upscaling / "+str(preset))
		await settle(3)
	await settle()
	for view in game.split_view.views:
		var post=view.find_child("*",false,false)
		check(view.scaling_3d_scale<=1.,"Split render scaling stays bounded")
	game.human_count=1;game.split_view.activate(false);game.hud.show_race();first.camera_view="cockpit";game.update_local_camera(first,1.)
	await shot("bigster-cockpit")
	first.camera_view="ghost";game.update_local_camera(first,1.);await shot("ghost")
	first.camera_view="chase";game.update_local_camera(first,1.);await shot("chase-reduced-motion")
	var instruments: LeoRaceInstruments=game.hud.unified_hud
	check(is_instance_valid(instruments),"Race instruments available")
	if is_instance_valid(instruments):
		check(not (instruments.speed.get_theme_font("font") as FontFile).multichannel_signed_distance_field,"Digital speed uses bundled non-MSDF font")
		await digit_pixels(instruments)
		measurements.digits=LeoSpeedDigits.diagnostic(instruments.speed,"regression",0)
		check(measurements.digits.glyphs and measurements.digits.raster_font,"Speed font contains decimal glyphs")
	print("RELEASE278_STAGE hulls")
	await collision_review()
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"measurements":measurements,"physical_4k_tv":"unverified / not connected by test"}
	FileAccess.open(output.path_join("release278.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("RELEASE278_TEST ",JSON.stringify(report));await game.quit_game(0 if errors.is_empty() else 1)

func settings() -> void:
	var cfg:=ConfigFile.new();cfg.set_value("game","best_time_astra",123.);cfg.set_value("unknown","keep","unchanged")
	game.graphics.read(cfg);game.graphics.write(cfg)
	check(cfg.get_value("game","best_time_astra")==123. and cfg.get_value("unknown","keep")=="unchanged","Settings retain legacy records and unknown keys")
	var before: Vector2i=game.graphics.resolution
	game.graphics.preview_display(Vector2i(1280,720),false)
	check(game.graphics.pending,"Display changes require confirmation")
	game.graphics.write(cfg);check(cfg.get_value("graphics","resolution")==before,"Unconfirmed resolution is not persisted")
	game.graphics.deadline=Time.get_ticks_msec()-1;game.graphics._process(0.)
	check(not game.graphics.pending and game.graphics.resolution==before,"Display timeout restores previous resolution")
	game.graphics.preview_display(Vector2i(1280,720),false);game.graphics.confirm_display()
	check(not game.graphics.pending and game.graphics.resolution==Vector2i(1280,720),"Confirmed display is retained")
	game.graphics.resolution=Vector2i(1920,1080)

func inputs() -> void:
	var keyboard:=LeoPlayerInput.new("keyboard");var pad:=LeoPlayerInput.new("gamepad")
	check(keyboard.bindings.change_camera[0].index==KEY_C,"C cycles camera by default")
	check(pad.bindings.change_camera[0].index==JOY_BUTTON_RIGHT_STICK,"Right-stick click cycles camera")
	var legacy:=keyboard.serialize();legacy.version=3;legacy.bindings.erase("change_camera");legacy.bindings.look_back=[{"type":"key","index":KEY_C}]
	keyboard.restore(legacy)
	check(keyboard.bindings.look_back[0].index==KEY_V and keyboard.bindings.change_camera[0].index==KEY_C,"Legacy default bindings migrate without conflict")
	legacy.keyboard_profiles={"shared1":legacy.bindings.duplicate(true)}
	keyboard.restore(legacy);keyboard.use_keyboard_preset("shared1")
	check(keyboard.bindings.change_camera[0].index==KEY_C and keyboard.bindings.look_back[0].index==KEY_V,"Saved shared-keyboard defaults gain camera view")
	legacy.custom_bindings=true;keyboard.restore(legacy)
	check(keyboard.bindings.look_back[0].index==KEY_C and keyboard.bindings.change_camera.is_empty(),"Custom bindings remain intact when C is occupied")

func contacts() -> void:
	var max_energy_delta:=0.
	for a in [Vector3(30,0,0),Vector3(30,0,10),Vector3.ZERO]:
		for b in [Vector3(-20,0,0),Vector3(10,0,4),Vector3.ZERO]:
			var result:=LeoContactSolver.pair_response(a,b,Vector3.LEFT)
			var delta: float=result[0].length_squared()+result[1].length_squared()-a.length_squared()-b.length_squared()
			max_energy_delta=maxf(max_energy_delta,delta)
			check(delta<=.001,"Pair contact never creates kinetic energy")
			check((result[0]+result[1]-a-b).length()<.001,"Pair contact conserves total momentum")
			check(result[0].z==a.z and result[1].z==b.z,"Glancing pair preserves tangential velocity")
	var addon:=VehicleDefinition.new();addon.official=false;addon.id=&"unreviewed"
	addon.camera_views={"cockpit":true,"eye":["invalid",1,0]}
	check(LeoCameraViews.available(addon)==["chase","ghost"],"Malformed optional cockpit metadata is ignored")
	addon.camera_views={"cockpit":true,"eye":[0,1,0],"rotation_degrees":[0,"invalid",0]}
	check(LeoCameraViews.profile(addon).is_empty(),"Malformed cockpit orientation is ignored")
	addon.contact_shapes=[{"size_fraction":["invalid",1,1],"center_fraction":[0,0,0]}]
	check(LeoCollisionShapes.definitions(addon).size()==1,"Malformed optional hull metadata uses original envelope")
	var old_mark:=Node3D.new();root.add_child(old_mark);LeoContactBudget.reserve_mark(old_mark);root.remove_child(old_mark)
	var new_mark:=Node3D.new();root.add_child(new_mark);LeoContactBudget.reserve_mark(new_mark)
	check(not LeoContactBudget.marks.any(func(item):return item.get_ref()==old_mark),"Detached race effects release their global budget immediately")
	old_mark.free();new_mark.free()
	measurements.max_pair_energy_delta=max_energy_delta
	check(LeoRaceRules.ID.begins_with("distinct_v4+contact_v278"),"Changed contacts have a separate record identity")

func free_space_reference() -> void:
	await game.hud.garage_selector.scheduler.pause_for_race()
	game.remove_racers()
	var subjects: Array[LeoKart]=[]
	for index in 2:
		var subject: LeoKart=load("res://tests/baseline271_drive.gd").new() if index==0 else LeoKart.new()
		game.add_child(subject);subject.local_slot=0;subject.setup(game.circuit,0,true,"human","bigster");LeoRaceRules.apply(subject)
		subject.set_physics_process(false);subject.active=true;subject.control_input=LeoPlayerInput.new();subject.collision_layer=0;subject.collision_mask=0;subject.boost_fuel=.4;subject.place(100.,0.)
		subjects.append(subject)
	var rows: Array=[]
	var error_speed:=0.;var error_fuel:=0.;var error_velocity:=0.;var error_heading:=0.
	for tick in 360:
		await physics_frame
		for subject in subjects:
			subject.position=game.circuit.sample(100.);subject.last_s=100.;subject.nearest_index=-1
			subject.control_input.inject_test("accelerate",1. if tick<240 or tick>=300 else 0.)
			subject.control_input.inject_test("brake",1. if tick>=240 and tick<300 else 0.)
			subject.control_input.inject_test("left",.25 if tick>=120 and tick<180 else 0.)
			subject.control_input.inject_test("right",.25 if tick>=180 and tick<240 else 0.)
			if tick==300:subject.boost(1.6,"reference")
			subject._physics_process(1./60.)
		error_speed=maxf(error_speed,absf(subjects[0].speed-subjects[1].speed))
		error_fuel=maxf(error_fuel,absf(subjects[0].boost_fuel-subjects[1].boost_fuel))
		error_velocity=maxf(error_velocity,(subjects[0].velocity-subjects[1].velocity).length())
		error_heading=maxf(error_heading,absf(angle_difference(subjects[0].rotation.y,subjects[1].rotation.y)))
		if tick%30==0:rows.append({"tick":tick,"baseline_speed":subjects[0].speed,"candidate_speed":subjects[1].speed,"baseline_fuel":subjects[0].boost_fuel,"candidate_fuel":subjects[1].boost_fuel})
	check(error_speed<.00001 and error_fuel<.00001 and error_velocity<.00001 and error_heading<.00001,"Bigster free-space driving matches original 2.7.1 controller")
	measurements.free_space={"reference_commit":"a34196e","max_speed_error":error_speed,"max_fuel_error":error_fuel,"max_velocity_error":error_velocity,"max_heading_error":error_heading,"samples":rows}
	for subject in subjects:subject.queue_free()
	await physics_frame

func digit_pixels(instruments: LeoRaceInstruments) -> void:
	instruments.set_process(false);game.hud.set_process(false)
	var label: Label=instruments.speed
	var original:=label.text
	label.text="";await settle(3);await RenderingServer.frame_post_draw
	var blank:=root.get_texture().get_image()
	var pixel_scale:=Vector2(blank.get_size())/root.get_visible_rect().size
	var bounds:=label.get_global_rect()
	var area:=Rect2i(Rect2(bounds.position*pixel_scale,bounds.size*pixel_scale)).intersection(Rect2i(Vector2i.ZERO,blank.get_size()))
	var results: Array=[]
	for number in ["000","099","199","249"]:
		label.text=number;await settle(3);await RenderingServer.frame_post_draw
		var digits:=root.get_texture().get_image();var changed:=0
		for y in range(area.position.y,area.end.y):
			for x in range(area.position.x,area.end.x):
				var a:=blank.get_pixel(x,y);var b:=digits.get_pixel(x,y)
				if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>.3:changed+=1
		check(changed>150,"Digital speed actually rasterizes / "+number)
		results.append({"text":number,"changed_pixels":changed})
	label.text=original;instruments.set_process(true);game.hud.set_process(true);measurements.digit_pixels=results

func collision_review() -> void:
	game.return_menu();game.human_count=1
	for key in ["bigster","duster","duster_2024"]:
		game.selected_kart=game.catalog.vehicle_index(StringName(key));await game.start_race();game.set_process(false);game.set_physics_process(false)
		for kart in game.karts:kart.set_physics_process(false)
		var kart: LeoKart=game.player;kart.place(100.,0.)
		await physics_frame;await physics_frame
		for rival in game.karts:
			if rival!=kart:rival.hide()
		var shapes:=LeoCollisionShapes.definitions(kart.definition)
		check(shapes.size()==2,"Reviewed two-primitive collision hull / "+key)
		check(not kart.damage.surfaces.is_empty(),"Reviewed body-only damage surfaces / "+key)
		for row in shapes:
			var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=row.size;mesh.mesh=box;mesh.position=row.position
			var material:=StandardMaterial3D.new();material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.albedo_color=Color(0.,1.,.8,.18);material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mesh.material_override=material;kart.add_child(mesh)
		var local: LeoLocalPlayer=game.local_players[0];local.camera_view="chase";local.camera_rig.orbit=Vector2(1.1,.12);local.camera_rig.orbit_idle=0.;game.update_local_camera(local,1./60.)
		await shot("collision-hull-"+key)
		var phases: Array=[];kart.contact_times.clear();kart.contact_reported.connect(func(event):phases.append(event.phase))
		for contact in 12:
			kart.report_contact(kart.global_position,Vector3.RIGHT,Vector3(-15.,0.,8.),null,"concrete");kart.contact_clock+=1./60.
		check(phases.count("impact")==1 and phases.count("scrape")==11,"Persistent contact does not repeat impact / "+key)
	check(LeoContactBudget.marks.size()<=256,"Global skid allocation stays within budget")
	game.return_menu();check(await game.select_track("kandy_lake"),"Night receiver test uses a street-lit track");game.human_count=1;game.selected_kart=game.catalog.vehicle_index(&"bigster");game.set_race_variant("dusk_night");await game.start_race()
	game.set_process(false);game.set_physics_process(false)
	for car in game.karts:car.set_physics_process(false)
	game.race_environment.displayed=1.;game.race_environment.apply(true)
	var local: LeoLocalPlayer=game.local_players[0];local.camera_view="ghost";game.update_local_camera(local,1.)
	var body: MeshInstance3D=game.player.chassis.find_children("*","MeshInstance3D",true,false)[0]
	check(bool(body.layers & (1<<16)),"Night street-light receiver layer survives camera tagging")
	check((body.layers & local.camera.cull_mask)==0,"Night receiver layer cannot reveal Ghost car")
	local.camera_view="chase";game.update_local_camera(local,1.)
	await shot("bigster-night-chase")
