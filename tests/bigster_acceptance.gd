extends SceneTree
var game: Node3D
var errors: Array[String]=[]
var checks:=0
var captures:=false
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+message)
	if not ok:errors.append(message)
func joy(button: JoyButton) -> void:
	var event:=InputEventJoypadButton.new();event.button_index=button;event.pressed=true;Input.parse_input_event(event)
	event=InputEventJoypadButton.new();event.button_index=button;event.pressed=false;Input.parse_input_event(event)
func capture(name_text: String) -> void:
	if not captures:return
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/qa-bigster/"+name_text+".png")
func ticks(count: int) -> void:
	for i in count:await physics_frame
func run() -> void:
	captures="--visual-test" in OS.get_cmdline_user_args()
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.diagnostics_mode=true;game.hud.show_garage()
	var selector: ModularCarSelector=game.hud.garage_selector
	var persistent:=selector.ui.get_instance_id();var field:=selector.name_field.get_instance_id()
	selector.name_field.text="COLOMBO PILOT";selector.custom_name=selector.name_field.text
	selector.race_button.grab_focus()
	var focus:=root.gui_get_focus_owner()
	selector.choose_vehicle(&"duster")
	check(selector.ui.get_instance_id()==persistent and selector.name_field.get_instance_id()==field,"Carousel updates persistent controls")
	check(selector.name_field.text=="COLOMBO PILOT" and root.gui_get_focus_owner()==focus,"Vehicle selection preserves text and focus")
	selector.driver_buttons[0].grab_focus();joy(JOY_BUTTON_DPAD_RIGHT);await process_frame
	check(root.gui_get_focus_owner()==selector.driver_buttons[1],"Xbox D-pad moves native focus")
	var motion:=InputEventJoypadMotion.new();motion.axis=JOY_AXIS_LEFT_X;motion.axis_value=.9;Input.parse_input_event(motion);await process_frame
	check(root.gui_get_focus_owner()==selector.driver_buttons[2],"Xbox left stick moves native focus")
	motion=InputEventJoypadMotion.new();motion.axis=JOY_AXIS_LEFT_X;motion.axis_value=0.;Input.parse_input_event(motion)
	joy(JOY_BUTTON_A);await process_frame;check(selector.driver_id==&"elephant","Xbox A activates the focused driver")
	selector.set_selection(&"mario",&"duster")
	check(selector.assembly.get_meta("driver_id")==&"mario" and selector.assembly.get_node("Driver").get_meta("visible_driver_id")==&"human","Dacia keeps selected identity and fixed helmeted driver")
	check(selector.stats.text.contains("165 KM/H"),"Duster displays real normal ceiling")
	selector.cycle_vehicle(-1);check(selector.vehicle_id==&"race_bus","Previous cycles catalog order")
	selector.set_selection(&"human",game.catalog.vehicles.back().id);joy(JOY_BUTTON_RIGHT_SHOULDER);await process_frame
	check(selector.vehicle_id==game.catalog.vehicles[0].id,"Xbox RB wraps all machines")
	joy(JOY_BUTTON_LEFT_SHOULDER);await process_frame
	check(selector.vehicle_id==game.catalog.vehicles.back().id,"Xbox LB wraps backwards")
	selector.name_field.grab_focus();var vehicle:=selector.vehicle_id;joy(JOY_BUTTON_RIGHT_SHOULDER);await process_frame
	check(selector.vehicle_id==vehicle,"Garage shortcuts suppressed while editing name")
	joy(JOY_BUTTON_A);await process_frame
	check(selector.keyboard.visible,"Controller A opens name-entry keyboard")
	joy(JOY_BUTTON_A);await process_frame
	check(selector.name_field.text=="COLOMBO PILOTA","Xbox A enters the focused keyboard character")
	joy(JOY_BUTTON_B);await process_frame
	check(not selector.keyboard.visible and selector.name_field.text=="COLOMBO PILOT","Xbox B cancels keyboard and restores typed name")
	selector.open_keyboard();selector.name_field.text="";selector.keyboard_append("L");selector.keyboard_append("E");selector.keyboard_append("O");selector.close_keyboard(false)
	check(selector.custom_name=="LEO" and selector.title.text=="LEO","Controller keyboard accepts custom name")
	selector.open_keyboard();await capture("controller-keyboard");selector.close_keyboard(false)
	var extra:=game.catalog.vehicles[0].duplicate(true) as VehicleDefinition;extra.id=&"carousel_expansion_probe";extra.display_name="A deliberately long future imported vehicle display name";game.catalog.vehicles.append(extra)
	selector.set_selection(&"human",extra.id);check(selector.counter.text=="17 / 17" and selector.machine.text==extra.display_name.to_upper(),"Catalog expansion requires no carousel code change")
	game.catalog.vehicles.pop_back();selector.set_selection(&"human",&"bigster")
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080)]:
		DisplayServer.window_set_size(resolution);root.size=resolution;await process_frame;game.hud.resize_canvas()
		check((Vector2(1600,900)*game.hud.scale+game.hud.position*2).is_equal_approx(game.hud.get_viewport_rect().size),"Centered scalable design canvas "+str(resolution))
		await capture("garage-%dx%d"%[resolution.x,resolution.y])
	root.size=Vector2i(1600,900);DisplayServer.window_set_size(root.size);game.hud.resize_canvas()
	selector.set_selection(&"human",&"duster");selector.yaw=-.72;selector.update_camera();await capture("white-duster")
	selector.set_selection(&"human",&"bigster");selector.yaw=-.7;selector.update_camera();await capture("grey-bigster")
	selector.set_selection(&"human",&"colombo_tuk");await capture("resized-tuk-tuk")
	for id in [&"blue",&"formula_red",&"roadster_gold",&"race_tuk",&"race_bus"]:
		selector.set_selection(&"human",id);selector.yaw=-1.2;selector.update_camera();await capture("seated-"+String(id))
	selector.reduced_motion=true;var yaw:=selector.yaw;selector._process(8.);check(selector.yaw==yaw,"Reduced Motion suppresses showroom rotation")
	selector.hide();check(selector.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Hidden preview suspends rendering");selector.show()
	for id in [&"duster",&"bigster"]:
		game.selected_kart=game.catalog.vehicle_index(id);game.start_race();game.state="race";game.player.active=true
		for k in game.karts:
			if k!=game.player:k.active=false;k.set_physics_process(false)
		game.player.place(80,0);game.player.boost_cooldown=20.;game.test_input("accelerate",1.);await ticks(220)
		check(absf(game.player.speed-game.player.max_speed)<.3,String(id)+" normal ceiling: "+str(game.player.speed*3.6)+" km/h")
		game.player.boost(1.6,"TEST");await ticks(36)
		check(absf(game.player.speed-game.player.boosted_ceiling())<.4,String(id)+" uses vehicle-specific boost ceiling")
		game.test_input("accelerate",0.)
		if id==&"bigster":
			game.player.boost_fuel=.1;game.test_input("brake",1.);await ticks(30);game.test_input("brake",0.)
			check(game.player.boost_time==0 and game.player.boost_fuel>.125,"Bigster braking cancels boost and modestly regenerates charge")
	game.start_race();game.state="race";game.player.active=true;game.player.place(600,0)
	game.player.progress=game.circuit.length+600;game.player.next_gate=11;game.player.lap=2;game.player.speed=60;game.player.boost(1.6,"TEST")
	game.race_time=84.125;game.best_time=500.
	var old: LeoKart=game.player;var old_selection:=Vector2i(game.selected_driver,game.selected_kart)
	var opponents: Array=game.karts.slice(1);var transforms: Array=opponents.map(func(k):return k.global_transform)
	game.toggle_pause();game.hud.show_garage("pause");selector=game.hud.garage_selector;selector.choose_vehicle(&"duster")
	await create_timer(.1,true,false,true).timeout
	check(game.paused and paused and game.player==old and game.race_time==84.125,"Pause garage freezes and retains the exact race")
	check(opponents.map(func(k):return k.global_transform)==transforms,"Opponents remain frozen")
	joy(JOY_BUTTON_B);await process_frame
	check(game.player==old and Vector2i(game.selected_driver,game.selected_kart)==old_selection and game.paused and not game.race_modified,"Cancel discards pending selection and returns to pause")
	game.hud.show_garage("pause");selector=game.hud.garage_selector;selector.choose_vehicle(&"duster");await capture("pause-garage")
	check(game.swap_player_vehicle(&"mario",&"duster","TEST PILOT"),"Continue swaps player into a collision-free lane")
	check(game.player!=old and game.race_time==84.125 and game.player.lap==2 and game.player.next_gate==11 and game.player.progress==game.circuit.length+600,"Swap preserves timer, lap, checkpoints and progress")
	check(game.karts.slice(1)==opponents and game.player.speed<=game.player.max_speed and game.player.boost_time==0,"Swap retains opponents, clamps speed and clears boost")
	check(game.race_modified and not game.paused and not paused and game.player.racer_name=="TEST PILOT","Modified race resumes with custom name")
	game.player.finish_time=100.;game.finish_race();check(game.best_time==500.,"Mid-race vehicle changes cannot update best-time records")
	game.start_race();check(not game.race_modified and game.player.next_gate==0 and game.race_time==0,"Start New Race resets the race normally")
	game.toggle_pause();game.hud.show_garage("pause");selector=game.hud.garage_selector;selector.race_requested.emit(&"human",&"bigster")
	check(not game.paused and game.state=="countdown" and game.player.vehicle_key=="bigster","Pause garage New Race applies the new selection")
	game.return_menu();game.hud.show_garage();joy(JOY_BUTTON_B);await process_frame
	check(game.state=="menu","Xbox B exits normal garage safely")
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"captures":captures}
	FileAccess.open("res://docs/qa-bigster/acceptance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("BIGSTER_ACCEPTANCE ",JSON.stringify(report))
	game.return_menu();game.stop_all_audio();game.queue_free();await process_frame;await process_frame;quit(0 if errors.is_empty() else 1)
