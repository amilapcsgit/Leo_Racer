extends SceneTree
var game: Node3D
var output: String
var errors: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:errors.append(text);push_error(text)
func settle(frames: int=6) -> void:
	for frame in frames:await process_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func pad(button: int,down: bool=true,device: int=7) -> void:
	var event:=InputEventJoypadButton.new();event.device=device;event.button_index=button;event.pressed=down
	Input.parse_input_event(event);await settle()
func run() -> void:
	output=ProjectSettings.globalize_path("res://build/qa270/final-fixes")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="):output=argument.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1920,1080);Engine.max_fps=60
	var content:=ProjectSettings.globalize_path("res://build/content-baseline/GameAssets") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("GameAssets")
	check(LeoAssets.configure(content)==OK and LeoAssets.mount_packs()==OK,"Content mounts")
	LeoVehicleLibrary.discover()
	game=load("res://scenes/main.tscn").instantiate();game.diagnostics_mode=true;root.add_child(game);await game.initialization_finished
	for course in game.tracks:
		FileAccess.open(output.path_join(course.id+".svg"),FileAccess.WRITE).store_string(LeoTrackHologram.route_svg(course))
	var router: LeoInputRouter=game.input_router
	router.players[0].switch_kind("gamepad");router.players[0].device=7;router.players[0].preference="manual"
	game.hud.frontend.show_setup(1);await settle()
	var toggle:=CheckButton.new();toggle.text="Confirmation fixture";game.hud.menu_root.add_child(toggle);toggle.position=Vector2(30,30);toggle.grab_focus()
	await pad(JOY_BUTTON_X)
	check(toggle.button_pressed,"Boost button toggles focused native control")
	await pad(JOY_BUTTON_X)
	check(toggle.button_pressed,"Held/repeated press does not confirm twice")
	await pad(JOY_BUTTON_X,false)
	await pad(JOY_BUTTON_X)
	check(not toggle.button_pressed,"Release rearms confirmation")
	await pad(JOY_BUTTON_X,false)
	router.players[0].bindings.boost=[{"type":"button","index":JOY_BUTTON_Y}]
	await pad(JOY_BUTTON_Y)
	check(toggle.button_pressed,"Remapped boost confirms")
	router.gameplay_enabled=true
	await pad(JOY_BUTTON_Y)
	check(not router.players[0].consume("boost"),"Held menu confirm cannot boost on race entry")
	await pad(JOY_BUTTON_Y,false)
	await pad(JOY_BUTTON_Y)
	check(router.players[0].consume("boost"),"New gameplay press boosts normally")
	await pad(JOY_BUTTON_Y,false);router.gameplay_enabled=false
	toggle.queue_free()
	var choice:=OptionButton.new();choice.add_item("First");choice.add_item("Second");game.hud.menu_root.add_child(choice);choice.position=Vector2(100,100);choice.grab_focus()
	await pad(JOY_BUTTON_Y);await pad(JOY_BUTTON_Y,false)
	check(choice.get_popup().visible,"Configured boost opens a dropdown")
	var down:=InputEventKey.new();down.keycode=KEY_DOWN;down.physical_keycode=KEY_DOWN;down.pressed=true;Input.parse_input_event(down);await settle()
	await pad(JOY_BUTTON_Y);await pad(JOY_BUTTON_Y,false)
	check(not choice.get_popup().visible,"Configured boost confirms dropdown selection")
	choice.queue_free()
	game.hud.frontend.show_settings();await settle()
	var settings_toggle: CheckButton=null
	for candidate in game.hud.modal_root.find_children("*","CheckButton",true,false):
		if candidate.visible:settings_toggle=candidate;break
	check(settings_toggle!=null,"Settings has native toggle")
	if settings_toggle:
		settings_toggle.grab_focus();var before:=settings_toggle.button_pressed
		await pad(JOY_BUTTON_Y);await pad(JOY_BUTTON_Y,false)
		check(settings_toggle.button_pressed!=before,"Configured boost operates real Settings toggle")
	game.hud.frontend.close_modal();await settle()
	game.selected_kart=game.catalog.vehicle_index(&"bigster");game.local_players[0].vehicle_id=&"bigster"
	game.hud.frontend.open_garage(0)
	while not game.hud.garage_selector.assembly:await process_frame
	await settle(12)
	var garage=game.hud.garage_selector
	var features:=garage.assembly.find_child("VehicleLighting",true,false) as LeoVehicleFeatures
	check(features!=null and features.action_name(1)=="Sunroof" and features.action_name(2)=="Trunk","Bigster retains sunroof and exposes trunk as Action 2")
	check(features.diagnostics.is_empty(),"Hatch reparenting preserves lamp bindings")
	var hinge:=garage.assembly.find_child("UltraTrunkHinge",true,false) as Node3D
	print("TRUNK_PARTS ",hinge.get_children().map(func(n):return n.name))
	check(hinge!=null and hinge.get_child_count()==10,"Complete hatch assembly includes shell, liner, badges, trim, lamp, glass and number plate, lettering and blue EU band")
	garage.yaw=PI;garage.update_camera();await settle()
	await shot("bigster-trunk-closed")
	features.trigger(2)
	for frame in 80:await process_frame
	check(hinge.rotation.x< -1.2,"Trunk opens around upper hinge")
	await shot("bigster-trunk-open")
	features.trigger(2)
	for frame in 80:await process_frame
	check(hinge.rotation.is_zero_approx(),"Trunk closes exactly")
	var second:=VehicleAssembler.assemble(game.catalog.vehicle(&"bigster"),game.catalog.drivers[0])
	var second_features:=second.find_child("VehicleLighting",true,false) as LeoVehicleFeatures
	features.trigger(2);features._process(1.2)
	check(second_features.actions[-1].progress==0.,"Split-screen cars have independent trunk state")
	features.trigger(2);features._process(1.2);second.free()
	garage.race_button.grab_focus();await pad(JOY_BUTTON_Y);await pad(JOY_BUTTON_Y,false)
	check(not garage.visible,"Configured boost confirms garage selection")
	game.selected_kart=game.catalog.vehicle_index(&"duster_2024");game.local_players[0].vehicle_id=&"duster_2024"
	await game.start_race();await settle(10)
	game.state="racing";game.player.active=true;game.player.boost(4.,"NITRO")
	await settle(12)
	game.countdown=0.;game.hud.announce("")
	check(game.player.flames.size()==2 and game.player.flames[0].visible,"Duster 2024 has two visible boost jets")
	check(game.player.exhaust_positions[0].z>game.player.definition.collision_position.z+game.player.definition.collision_size.z*.5,"Jets start behind rear body")
	await shot("duster-2024-boost")
	game.player.boost_time=0.;await settle()
	check(not game.player.flames[0].visible,"Boost jets stop with boost")
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors}
	FileAccess.open(output.path_join("finish.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ULTRA_FINISH_TEST ",JSON.stringify(report));await game.quit_game(0 if errors.is_empty() else 1)
