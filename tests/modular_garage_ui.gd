extends SceneTree
var game: Node3D
var errors: Array[String]=[]
var checks := 0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func capture(name_text: String) -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/qa-modular-garage/"+name_text+".png")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.diagnostics_mode=true;game.hud.show_garage()
	var selector: ModularCarSelector=game.hud.garage_selector
	check(selector.viewport.own_world_3d,"Showroom has an isolated World3D")
	check(selector.driver_buttons.size()==6 and selector.vehicle_buttons.size()==9,"Six portraits and nine vehicle cards")
	var focused:=root.gui_get_focus_owner()
	var key:=InputEventKey.new();key.keycode=KEY_RIGHT;key.pressed=true;Input.parse_input_event(key)
	await process_frame
	check(root.gui_get_focus_owner()!=focused,"Keyboard spatial focus moves between driver cards")
	key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=true;Input.parse_input_event(key)
	await process_frame
	key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=false;Input.parse_input_event(key)
	await process_frame
	check(game.selected_driver==1,"Keyboard confirm selects the focused racer")
	var pad:=InputEventJoypadButton.new();pad.button_index=JOY_BUTTON_A;pad.pressed=true;Input.parse_input_event(pad)
	await process_frame
	check(is_instance_valid(root.gui_get_focus_owner()),"Controller confirm retains a valid focused card")
	selector.change_page(1);check(selector.vehicle_buttons.size()==7 and selector.vehicle_page==1,"Second page contains seven supplied cars")
	selector.choose_driver(&"human");selector.choose_vehicle(&"duster")
	check(selector.assembly.get_node_or_null("Driver")==null,"Supplied car preview has no added driver")
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080)]:
		DisplayServer.window_set_size(resolution);root.size=resolution;await process_frame;game.hud.resize_canvas()
		await capture("garage-%dx%d"%[resolution.x,resolution.y])
		for button in selector.driver_buttons+selector.vehicle_buttons:
			check(button.get_global_rect().size.x>40 and button.get_global_rect().size.y>40,"Readable card at "+str(resolution))
	selector.choose_vehicle(&"blue");await capture("helmeted-shaven-leo")
	check(selector.assembly.get_node_or_null("Driver")!=null,"Existing open kart shows helmeted racer")
	selector.choose_driver(&"mario");await capture("mario-open-kart")
	selector.reduced_motion=true;var yaw:=selector.yaw;selector._process(6.);check(yaw==selector.yaw,"Reduced Motion stops automatic orbit")
	var motion:=InputEventMouseMotion.new();motion.relative=Vector2(30,5);selector.dragging=true;selector._gui_input(motion);selector.dragging=false;check(selector.yaw!=yaw,"Drag orbit changes view")
	selector.reset_view();check(selector.zoom==1. and selector.yaw==-.6,"Reset restores camera framing")
	selector.hide();check(selector.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and not selector.is_processing(),"Hidden showroom stops rendering and processing");selector.show()
	var extra:=game.catalog.vehicles[0].duplicate(true) as VehicleDefinition;extra.id=&"extra_ui_probe";extra.display_name="A VERY LONG FUTURE VEHICLE DISPLAY NAME";game.catalog.vehicles.append(extra);selector.set_selection(&"mario",extra.id);check(selector.vehicle_page==1 and selector.vehicle_buttons.size()==8,"Expansion updates page cardinality without UI code edits");await capture("catalog-expansion-probe");game.catalog.vehicles.pop_back()
	var d:=game.catalog.drivers[0].duplicate() as DriverDefinition;d.id=&"seventh_driver_probe";game.catalog.drivers.append(d);selector.set_selection(d.id,&"blue");check(selector.driver_page==1 and selector.driver_buttons.size()==1,"Driver pagination expands beyond six");game.catalog.drivers.pop_back()
	selector.set_selection(&"human",&"blue")
	selector.race_requested.emit(&"human",&"blue");await process_frame
	check(game.player.driver!=null and game.player.visual.get_meta("driver_id")==&"human","Race startup receives stable IDs and shared assembly")
	check(selector.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Race hides and freezes the garage viewport")
	game.toggle_pause();await create_timer(.1,true).timeout;game.toggle_pause();game.player.recover();game.start_race();game.return_menu()
	check(game.state=="menu" and game.karts.is_empty(),"Pause, recovery, restart and menu return")
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","errors":errors,"checks":checks,"resolutions":["1280x720","1920x1080","2560x1080"]}
	FileAccess.open("res://docs/qa-modular-garage/garage-ui.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("MODULAR_GARAGE_UI_REPORT ",report.status," checks=",checks)
	game.stop_all_audio();game.queue_free();await process_frame;await process_frame;quit(0 if errors.is_empty() else 1)
