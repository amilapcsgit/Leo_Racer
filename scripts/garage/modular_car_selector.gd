class_name ModularCarSelector
extends Control
signal selection_changed(driver_id: StringName, vehicle_id: StringName)
signal race_requested(driver_id: StringName, vehicle_id: StringName)
signal name_changed(value: String)
signal continue_requested(driver_id: StringName, vehicle_id: StringName)
signal back_requested
var custom_name := ""
var input_device := -2
var race_context := false
var name_field: LineEdit
var race_button: Button
var back_button: Button
var previous_button: Button
var next_button: Button
var carousel: LeoDriverCarousel
var player_slot := -1
var ring_materials: Array[StandardMaterial3D]=[]
var ring_tween: Tween
var keyboard_first: Button
var keyboard: Control
var keyboard_original := ""
var keyboard_caption: Label
var caption: Label
var policy: Label
var counter: Label
var catalog: GarageCatalog
var driver_id: StringName = &"hedgehog"
var vehicle_id: StringName = &"blue"
var reduced_motion := false
var assembly: Node3D
var selection_generation := 0
var preview_fade: Tween
var capture_busy := false
var loading_preview: TextureRect
var loading_caption: Label
var warm_only := false
var home_preview:=false
var scheduler: LeoPreviewScheduler
var preview_actions: Array[Button]=[]
var vehicle_cards: Dictionary={}
var vehicle_strip: ScrollContainer
var driver_caption: Label
signal preview_ready
var driver_buttons: Array[Button] = []
var ui: Control
var title: Label
var machine: Label
var identity: Label
var stats: Label
var stat_bars: Array[LeoStatBar]=[]
var stat_labels: Array[Label]=[]
var portrait_tweens: Dictionary={}
var keyboard_suspended: Array[Control]=[]
var camera: Camera3D
var yaw := 0.
var pitch := .12
var zoom := 1.0
var dragging := false
var idle := 0.0
var showroom_parallax:=Vector2.ZERO
var base_distance := 8.0
var target := Vector3(0,1,0)
var cream := Color("f3e5ca")
var brass := Color("d6b77a")
var cyan := Color("67d6db")
var font: Font = preload("res://assets/fonts/BarlowCondensed-BoldItalic.ttf")
@onready var showroom: Node3D = $SubViewportContainer/SubViewport/Garage3D
@onready var viewport: SubViewport = $SubViewportContainer/SubViewport

func _ready() -> void:
	add_to_group("controller_garage")
	theme=load("res://assets/ui/theme.tres")
	if not catalog: catalog=GarageCatalog.shared()
	var surround := ColorRect.new()
	surround.position=Vector2(-2000,0);surround.size=Vector2(5600,900)
	surround.color=Color("17140f");surround.mouse_filter=MOUSE_FILTER_IGNORE;add_child(surround);move_child(surround,0)
	var background := TextureRect.new()
	background.texture=preload("res://assets/ui/art/garage-skyline-v26.png")
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter=MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background,1)
	var dim:=ColorRect.new();dim.color=Color(.015,.025,.04,.48);dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT);dim.mouse_filter=MOUSE_FILTER_IGNORE;add_child(dim);move_child(dim,2)
	var atmosphere:=LeoBackdropFX.new();atmosphere.art=background;atmosphere.reduced_motion=reduced_motion;add_child(atmosphere)
	scheduler=LeoPreviewScheduler.new();scheduler.catalog=catalog;add_child(scheduler)
	build_showroom()
	build_interface()
	if not warm_only:set_selection(driver_id,vehicle_id)
	visibility_changed.connect(sync_visibility)
	sync_visibility()

func configure(data: GarageCatalog, d: StringName, v: StringName, reduced: bool) -> void:
	catalog=data;driver_id=d;vehicle_id=v;reduced_motion=reduced
	if is_node_ready():reset_view()

func kit(region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas=preload("res://assets/art/garage/hud_kit.svg")
	atlas.region=region
	return atlas

func panel(parent: Node,rect: Rect2) -> Panel:
	var node:=Panel.new();node.position=rect.position;node.size=rect.size
	var box:=StyleBoxFlat.new();box.bg_color=Color("101722a8");box.border_color=Color("526372");box.set_border_width_all(1);box.set_corner_radius_all(16);box.shadow_color=Color(0,0,0,.5);box.shadow_size=12
	node.add_theme_stylebox_override("panel",box);node.mouse_filter=MOUSE_FILTER_IGNORE;parent.add_child(node);return node

func label(parent: Node, words: String, font_size: int, color: Color=cream) -> Label:
	var node := Label.new()
	node.text=words;node.add_theme_font_override("font",font)
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.mouse_filter=MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func positioned_label(words: String, pos: Vector2, font_size: int, color: Color=cream) -> Label:
	var node := label(ui,words,maxi(font_size,20),color);node.position=pos
	return node

func button(parent: Node,words: String,action: Callable,selected:=false) -> Button:
	var node: LeoActionButton=load("res://scenes/ui/ActionButton.tscn").instantiate()
	node.text=words;node.sound_key="back" if words=="Back" else "select";node.primary=selected;node.reduced_motion=reduced_motion;node.pressed.connect(action);parent.add_child(node);node.custom_minimum_size.y=44
	return node

func build_interface() -> void:
	if ui:return
	process_mode=Node.PROCESS_MODE_ALWAYS
	ui=Control.new();ui.set_anchors_and_offsets_preset(PRESET_FULL_RECT);ui.mouse_filter=MOUSE_FILTER_IGNORE;add_child(ui)
	positioned_label("COLOMBO MOTOR CLUB / GARAGE",Vector2(32,28),24,cyan)
	panel(ui,Rect2(24,146,280,132))
	panel(ui,Rect2(1268,176,300,292))
	name_field=LineEdit.new();name_field.position=Vector2(40,160);name_field.size=Vector2(248,44);name_field.max_length=32;name_field.text=custom_name;name_field.add_theme_font_size_override("font_size",22);ui.add_child(name_field)
	name_field.text_changed.connect(func(value: String):custom_name=value;refresh_labels();name_changed.emit(value))
	var keys:=button(ui,"Change Name",open_keyboard);keys.position=Vector2(40,216);keys.size=Vector2(248,44)
	driver_caption=positioned_label("YOUR DRIVER",Vector2(32,484),18,cyan)
	carousel=LeoDriverCarousel.new();carousel.compact=true;carousel.catalog=catalog;carousel.reduced_motion=reduced_motion;carousel.position=Vector2(32,518);ui.add_child(carousel);carousel.driver_selected.connect(choose_driver);driver_buttons=carousel.cards
	caption=positioned_label("",Vector2(32,638),18,Color("b9c7d6"));caption.size=Vector2(440,28);caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for i in 4:
		var stat:=positioned_label("",Vector2(1290,230+i*54),20,cream);stat_labels.append(stat)
		var bar:=LeoStatBar.new();bar.position=Vector2(1290,258+i*54);bar.custom_minimum_size=Vector2(250,8);bar.size=Vector2(250,8);bar.reduced_motion=reduced_motion;ui.add_child(bar);stat_bars.append(bar)
	title=positioned_label("",Vector2(32,64),20,Color("b9c7d6"));title.size=Vector2(990,30)
	machine=positioned_label("",Vector2(30,90),42,cream);machine.size=Vector2(1000,52);machine.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;machine.clip_text=true
	counter=positioned_label("",Vector2(1464,96),22,cyan)
	identity=positioned_label("YOUR RIDE / YOUR COAST",Vector2(564,638),18,cyan)
	policy=positioned_label("",Vector2(384,126),18);policy.hide()
	previous_button=button(ui,"‹",func():cycle_vehicle(-1));previous_button.position=Vector2(320,370);previous_button.size=Vector2(48,72)
	next_button=button(ui,"›",func():cycle_vehicle(1));next_button.position=Vector2(1214,370);next_button.size=Vector2(48,72)
	positioned_label("VEHICLE PERFORMANCE",Vector2(1290,190),20,cyan)
	for slot in [0,1,2]:
		var action_slot: int=slot
		var control:=button(ui,["Lights","Doors","Trunk"][slot],func():preview_action(action_slot));control.position=Vector2(32,300+slot*52);control.size=Vector2(180,42);preview_actions.append(control)
	stats=positioned_label("",Vector2.ZERO,20);stats.hide()
	positioned_label("Drag to orbit · Scroll to zoom · LB / RB ride · Boost button: OK",Vector2(564,610),20,Color("b9c7d6"))
	vehicle_strip=ScrollContainer.new();vehicle_strip.position=Vector2(32,674);vehicle_strip.size=Vector2(1536,138);vehicle_strip.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;vehicle_strip.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER;ui.add_child(vehicle_strip)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);vehicle_strip.add_child(row)
	for vehicle in catalog.vehicles:
		var id: StringName=vehicle.id
		var card:=Button.new();card.custom_minimum_size=Vector2(209,134);card.toggle_mode=true;card.tooltip_text=vehicle.display_name;row.add_child(card);vehicle_cards[id]=card
		var normal:=StyleBoxFlat.new();normal.bg_color=Color(.025,.045,.065,.75);normal.border_color=Color(.25,.36,.4,.6);normal.set_border_width_all(1);normal.set_corner_radius_all(5);card.add_theme_stylebox_override("normal",normal)
		var selected:=normal.duplicate() as StyleBoxFlat;selected.bg_color=Color(.04,.16,.20,.86);selected.border_color=cyan;selected.set_border_width_all(2)
		for state in ["pressed","hover","focus"]:card.add_theme_stylebox_override(state,selected)
		add_card_content(card,LeoPreviewArt.name_for(vehicle),LeoPreviewArt.texture(vehicle),Vector2(196,96),20)
		card.pressed.connect(func():choose_vehicle(id));card.focus_entered.connect(func():scheduler.hint(id));card.mouse_entered.connect(func():scheduler.hint(id))
	back_button=button(ui,"Back",func():back_requested.emit());back_button.position=Vector2(32,838);back_button.size=Vector2(176,44)
	var reset:=button(ui,"Reset View",reset_view);reset.position=Vector2(1090,838);reset.size=Vector2(176,44)
	race_button=button(ui,"Keep Racing" if race_context else "Use This Ride",func():
		if race_context:continue_requested.emit(driver_id,vehicle_id)
		else:race_requested.emit(driver_id,vehicle_id),true)
	race_button.position=Vector2(1282,838);race_button.size=Vector2(280,44)
	var controls: Array[Control]=[name_field,keys,carousel,previous_button,next_button,reset,race_button,back_button]
	controls.append_array(preview_actions)
	for card in vehicle_cards.values():controls.append(card)
	for i in controls.size():
		controls[i].focus_next=controls[i].get_path_to(controls[(i+1)%controls.size()]);controls[i].focus_previous=controls[i].get_path_to(controls[posmod(i-1,controls.size())])
	carousel.focus_neighbor_bottom=carousel.get_path_to(vehicle_cards[vehicle_id]);race_button.focus_neighbor_left=race_button.get_path_to(back_button)
	build_keyboard()

func refresh_labels() -> void:
	if driver_caption:driver_caption.text=("PLAYER %d · " % (player_slot+1) if player_slot>=0 else "")+"CHOOSE YOUR DRIVER"
	if not ui:return
	var d:=catalog.driver(driver_id);var v:=catalog.vehicle(vehicle_id)
	title.text=(d.display_name if custom_name.strip_edges().is_empty() else custom_name.strip_edges()).to_upper()
	machine.text=v.display_name.to_upper();counter.text="%02d / %02d"%[catalog.vehicle_index(vehicle_id)+1,catalog.vehicles.size()]
	name_field.placeholder_text=d.display_name
	identity.text="%d RACERS × %d MACHINES // YOUR COMBO. YOUR COAST."%[catalog.drivers.size(),catalog.vehicles.size()]
	caption.text=d.tagline
	for id in vehicle_cards:vehicle_cards[id].set_pressed_no_signal(id==vehicle_id)
	vehicle_strip.ensure_control_visible(vehicle_cards[vehicle_id])
	stats.text="TOP SPEED     %03d KM/H\nBOOST SPEED   %03d KM/H\nCORNER GRIP   %.2f\nLAUNCH POWER  %.1f M/S²"%[roundi(float(LeoRaceRules.resolve(v).max_speed)*3.6),roundi(float(LeoRaceRules.resolve(v).boosted_speed)*3.6),float(LeoRaceRules.resolve(v).handling),float(LeoRaceRules.resolve(v).acceleration)]
	var rules:=LeoRaceRules.resolve(v)
	var values: Array[float]=[float(rules.max_speed)*3.6,float(rules.boosted_speed)*3.6,float(rules.handling),float(rules.acceleration)]
	var maxima: Array[float]=[0.,0.,0.,0.]
	for vehicle in catalog.vehicles:
		var resolved:=LeoRaceRules.resolve(vehicle)
		maxima[0]=maxf(maxima[0],float(resolved.max_speed)*3.6);maxima[1]=maxf(maxima[1],float(resolved.boosted_speed)*3.6);maxima[2]=maxf(maxima[2],float(resolved.handling));maxima[3]=maxf(maxima[3],float(resolved.acceleration))
	for i in 4:
		stat_bars[i].set_value(values[i]/maxf(.001,maxima[i]))
		stat_labels[i].text=["Speed · %d km/h" % roundi(values[0]),"Boost · %d km/h" % roundi(values[1]),"Grip · %.2f" % values[2],"Launch · %.1f m/s²" % values[3]][i]
	policy.text="SELECTED RACER // CABIN POSE" if v.driver_policy==VehicleDefinition.DriverPolicy.CABIN else "HELMETED SHAVEN LEO // FIXED CABIN DRIVER" if v.driver_policy==VehicleDefinition.DriverPolicy.FIXED else ("IDENTITY + PORTRAIT // DRIVER-FREE BODY" if v.driver_policy==VehicleDefinition.DriverPolicy.IDENTITY_ONLY else "OPEN COCKPIT // LIVE DRIVER")
	if not v.official:policy.text+=" · MODDED / NO OFFICIAL RECORDS"
	carousel.select_id(driver_id)

func cycle_vehicle(direction: int) -> void:
	scheduler.direction=signi(direction)
	choose_vehicle(catalog.vehicles[posmod(catalog.vehicle_index(vehicle_id)+direction,catalog.vehicles.size())].id)

func cycle_driver(direction: int) -> void:
	carousel.step(direction)

func build_keyboard() -> void:
	keyboard=Control.new();keyboard.set_anchors_and_offsets_preset(PRESET_FULL_RECT);ui.add_child(keyboard)
	var shade:=ColorRect.new();shade.color=Color(0,0,0,.82);shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT);keyboard.add_child(shade)
	panel(keyboard,Rect2(300,220,1000,520));keyboard_caption=label(keyboard,"",32);keyboard_caption.position=Vector2(340,248)
	var grid:=GridContainer.new();grid.columns=10;grid.position=Vector2(340,315);grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);keyboard.add_child(grid)
	for character in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-.":
		var key:=button(grid,character,func():keyboard_append(character));key.custom_minimum_size=Vector2(83,56)
		if not keyboard_first:keyboard_first=key
	var space:=button(keyboard,"SPACE",func():keyboard_append(" "));space.position=Vector2(340,601);space.size=Vector2(200,55)
	var erase:=button(keyboard,"DELETE",func():name_field.text=name_field.text.left(-1);keyboard_sync());erase.position=Vector2(555,601);erase.size=Vector2(200,55)
	var done:=button(keyboard,"DONE",func():close_keyboard(false),true);done.position=Vector2(770,601);done.size=Vector2(200,55)
	var cancel:=button(keyboard,"CANCEL",func():close_keyboard(true));cancel.position=Vector2(985,601);cancel.size=Vector2(200,55)
	keyboard.hide()

func open_keyboard() -> void:
	keyboard_suspended.clear()
	for control in ui.find_children("*","Control",true,false):
		if not keyboard.is_ancestor_of(control) and control.focus_mode!=Control.FOCUS_NONE:
			control.set_meta("keyboard_focus_mode",control.focus_mode);control.focus_mode=Control.FOCUS_NONE;keyboard_suspended.append(control)
	keyboard_original=name_field.text;keyboard_caption.text=name_field.text;keyboard.show();keyboard_first.grab_focus()

func keyboard_append(character: String) -> void:
	if name_field.text.length()<32:name_field.text+=character
	keyboard_sync()

func keyboard_sync() -> void:
	custom_name=name_field.text;keyboard_caption.text=custom_name;refresh_labels()

func close_keyboard(cancelled: bool) -> void:
	for control in keyboard_suspended:
		if is_instance_valid(control):control.focus_mode=int(control.get_meta("keyboard_focus_mode",Control.FOCUS_ALL))
	keyboard_suspended.clear()
	if cancelled:name_field.text=keyboard_original
	keyboard_sync();keyboard.hide();race_button.grab_focus();name_changed.emit(custom_name)

func activate_controller_focus() -> void:
	var target_viewport:=get_viewport()
	var focused:=target_viewport.gui_get_focus_owner()
	target_viewport.set_input_as_handled()
	if focused is Button and is_ancestor_of(focused) and not focused.disabled:
		focused.pressed.emit()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not ui:return
	var router:=get_tree().get_first_node_in_group("menu_input_router")
	if router and router.menu_confirm(event):return
	if input_device!=-2 and (event is InputEventJoypadButton or event is InputEventJoypadMotion) and event.device!=input_device:
		get_viewport().set_input_as_handled();return
	var input_viewport:=get_viewport()
	if keyboard.visible:
		if (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_B) or (event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE):close_keyboard(true);input_viewport.set_input_as_handled()
		elif event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_A:activate_controller_focus()
		return
	if name_field.has_focus():
		if event is InputEventJoypadButton and event.pressed:
			if event.button_index==JOY_BUTTON_A:open_keyboard()
			elif event.button_index==JOY_BUTTON_B:race_button.grab_focus()
			input_viewport.set_input_as_handled()
		elif event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER,KEY_ESCAPE]:race_button.grab_focus();input_viewport.set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index==JOY_BUTTON_LEFT_SHOULDER:cycle_vehicle(-1)
		elif event.button_index==JOY_BUTTON_RIGHT_SHOULDER:cycle_vehicle(1)
		elif event.button_index==JOY_BUTTON_B:back_requested.emit()
		elif event.button_index==JOY_BUTTON_A:activate_controller_focus()
		else:return
		input_viewport.set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEUP,KEY_PAGEDOWN]:cycle_vehicle(-1 if event.keycode==KEY_PAGEUP else 1);input_viewport.set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:back_requested.emit();input_viewport.set_input_as_handled()

func add_card_content(b: Button, name_text: String, texture: Texture2D, image_size: Vector2, fs: int) -> void:
	var box := VBoxContainer.new();box.set_anchors_and_offsets_preset(PRESET_FULL_RECT);box.offset_left=5;box.offset_right=-5;box.offset_top=3;box.offset_bottom=-4;box.mouse_filter=MOUSE_FILTER_IGNORE;b.add_child(box)
	var pic := TextureRect.new();pic.texture=texture;pic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;pic.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;pic.custom_minimum_size=image_size;pic.size_flags_vertical=SIZE_EXPAND_FILL;pic.mouse_filter=MOUSE_FILTER_IGNORE;box.add_child(pic)
	var text := label(box,name_text.to_upper(),fs);text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;text.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;text.clip_text=true;text.custom_minimum_size.x=0

func valid_selection(generation: int) -> bool:
	return is_inside_tree() and generation==selection_generation and (is_visible_in_tree() or home_preview)

func prefetch_neighbors(_generation: int) -> void:
	scheduler.anticipate(driver_id,vehicle_id)

func _exit_tree() -> void:
	selection_generation+=1
	if preview_fade:preview_fade.kill()
	if ring_tween:ring_tween.kill()

func set_selection(d: StringName,v: StringName) -> void:
	if is_node_ready():viewport.msaa_3d=get_tree().root.msaa_3d
	var changed:=vehicle_id!=v
	driver_id=d;vehicle_id=v
	if not is_node_ready():return
	selection_generation+=1
	if preview_fade:preview_fade.kill()
	var generation:=selection_generation
	var car:=catalog.vehicle(v)
	var racer:=catalog.driver(d)
	if not car or not racer:
		machine.text="PREVIEW UNAVAILABLE"
		policy.text="This selection is unavailable. Choose another ride or driver."
		race_button.disabled=true
		if is_instance_valid(assembly):assembly.hide()
		if loading_preview:loading_preview.hide()
		if loading_caption:loading_caption.hide()
		return
	refresh_labels()
	var start_time:=Time.get_ticks_usec()
	if not loading_preview:
		loading_preview=TextureRect.new();loading_preview.position=Vector2.ZERO;loading_preview.size=Vector2(1600,900);loading_preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;loading_preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;loading_preview.mouse_filter=MOUSE_FILTER_IGNORE;add_child(loading_preview);move_child(loading_preview,ui.get_index())
		loading_caption=positioned_label("",Vector2(700,570),22,cyan)
	var initial:=LeoVehiclePresentation.resolve(car)
	base_distance=initial.preview_distance*.95;target=initial.preview_target-Vector3.UP*.4
	showroom_parallax=Vector2.ZERO;reset_view()
	loading_preview.texture=LeoPreviewArt.texture(car,true)
	var generic:=loading_preview.texture.resource_path.ends_with("/custom-car.png")
	loading_preview.position=Vector2(500,220) if generic else Vector2.ZERO;loading_preview.size=Vector2(600,400) if generic else Vector2(1600,900)
	loading_preview.modulate.a=1.;loading_preview.show();loading_caption.text="Loading your ride…";loading_caption.show();race_button.disabled=true
	if is_instance_valid(assembly):assembly.hide()
	for control in preview_actions:control.disabled=true
	var current:=func():return valid_selection(generation)
	scheduler.suspended=false
	var prepared:=await scheduler.acquire(d,v,current)
	if not prepared:
		if current.call():loading_caption.text="Preview unavailable / check content"
		return
	if not current.call():return
	if is_instance_valid(assembly) and assembly!=prepared:scheduler.park(assembly)
	assembly=prepared
	if assembly.get_parent()!=showroom:assembly.reparent(showroom)
	var preview_driver:=assembly.get_node_or_null("Driver") as Node3D
	if preview_driver:preview_driver.hide()
	assembly.show()
	refresh_preview_actions()
	var presented:=LeoVehiclePresentation.resolve(car)
	base_distance=presented.preview_distance*.95;target=presented.preview_target-Vector3.UP*.4
	if changed:reset_view()
	else:update_camera()
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	if not current.call():return
	loading_caption.hide();race_button.disabled=false;idle=0.
	if reduced_motion:loading_preview.hide()
	else:
		preview_fade=create_tween()
		preview_fade.tween_property(loading_preview,"modulate:a",0.,.18)
		preview_fade.tween_callback(func():
			if generation==selection_generation:loading_preview.hide())
	LeoPreviewStream.timings.append({"vehicle":String(v),"stage":"first_visible","ms":(Time.get_ticks_usec()-start_time)/1000.})
	refresh_labels()
	pulse_rings()
	preview_ready.emit()
	prefetch_neighbors(generation)
	if not car.official and not FileAccess.file_exists(LeoPreviewArt.cache_path(car,true)):
		await capture_art(ProjectSettings.globalize_path(LeoPreviewArt.cache_path(car,true)),ProjectSettings.globalize_path(LeoPreviewArt.cache_path(car,false)))

func preview_features() -> LeoVehicleFeatures:
	if not is_instance_valid(assembly):return null
	return assembly.get_node_or_null("Chassis/VehicleLighting") as LeoVehicleFeatures

func refresh_preview_actions() -> void:
	var features:=preview_features()
	for slot in preview_actions.size():
		preview_actions[slot].disabled=not features or (slot==0 and features.groups.is_empty()) or (slot>0 and features.action_name(slot)=="Unassigned")
		if slot>0:preview_actions[slot].text=features.action_name(slot) if features and features.action_name(slot)!="Unassigned" else ["","Doors","Trunk"][slot]

func preview_action(slot: int) -> void:
	var features:=preview_features()
	if not features:return
	if slot==0:features.toggle_headlights()
	else:features.trigger(slot)

func choose_driver(id: StringName) -> void:
	set_selection(id,vehicle_id);selection_changed.emit(driver_id,vehicle_id)

func choose_vehicle(id: StringName) -> void:
	set_selection(driver_id,id);selection_changed.emit(driver_id,vehicle_id)

func reset_view() -> void:
	yaw=0.;pitch=.12;zoom=1.;idle=0.;update_camera()

func update_camera() -> void:
	if not camera:return
	camera.position=target+Vector3(sin(yaw)*cos(pitch),sin(pitch),-cos(yaw)*cos(pitch))*base_distance*zoom+Vector3(showroom_parallax.x*.12,showroom_parallax.y*.05,0)
	camera.look_at(target)

func sync_visibility() -> void:
	if not is_visible_in_tree() and not home_preview:selection_generation+=1
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if is_visible_in_tree() or home_preview else SubViewport.UPDATE_DISABLED
	set_process(is_visible_in_tree() or home_preview);set_process_input(is_visible_in_tree())

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and Rect2(310,140,950,460).has_point(event.position):
		if event.button_index==MOUSE_BUTTON_LEFT:dragging=event.pressed;accept_event()
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom=clampf(zoom+(-.08 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .08),.65,1.5);idle=0.;update_camera();accept_event()
	if event is InputEventMouseMotion and dragging:
		yaw+=event.relative.x*.008;pitch=clampf(pitch+event.relative.y*.004,.06,.65);idle=0.;update_camera();accept_event()

func _process(dt: float) -> void:
	if get_tree().paused and not race_context:return
	idle+=dt
	var pointer:=Vector2.ZERO if reduced_motion or (loading_preview and loading_preview.visible) else (get_local_mouse_position()/Vector2(1600,900)*2.-Vector2.ONE).clamp(-Vector2.ONE,Vector2.ONE)
	showroom_parallax=showroom_parallax.lerp(pointer,1.-exp(-dt*5.))
	if not reduced_motion and not dragging and not race_button.disabled and idle>2.:yaw+=dt*.12
	if not dragging and not capture_busy:update_camera()

func prewarm_materials() -> void:
	# OpenGL has no background pipeline compilation. Compile tiny material
	# representatives behind the boot screen, retaining only lightweight resources.
	if RenderingServer.get_current_rendering_method()!="gl_compatibility":return
	var seen: Dictionary={}
	for vehicle in catalog.vehicles:
		var path:=String(vehicle.content_data.get("shader_warmup_scene",""))
		if path.is_empty():continue
		if ResourceLoader.load_threaded_request(path,"PackedScene")!=OK:continue
		while ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:await get_tree().process_frame
		if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_LOADED:continue
		var scene:=ResourceLoader.load_threaded_get(path) as PackedScene
		LeoPreviewStream.shader_warmups.append(scene)
		var proxies:=scene.instantiate();showroom.add_child(proxies)
		for proxy in proxies.get_children():
			var material: Material=proxy.mesh.surface_get_material(0)
			var features: PackedStringArray=[]
			for property in material.get_property_list():
				if not int(property.usage)&PROPERTY_USAGE_STORAGE:continue
				var value: Variant=material.get(property.name)
				if value is Texture2D:features.append(String(property.name)+"=texture")
				elif value is bool or (value is int and int(property.hint)==PROPERTY_HINT_ENUM):features.append(String(property.name)+"="+str(value))
			var shader: String=";".join(features)
			if seen.has(shader):continue
			seen[shader]=true;proxy.show()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			proxy.hide()
		proxies.free()
	# Driver albedo/vertex-color combinations are independent of car paint.
	# Keep their small compiled resources in the existing driver cache.
	for racer in catalog.drivers:
		for path in [racer.seated_model_path,racer.cabin_model_path]:
			if path.is_empty():continue
			var scene: PackedScene=await LeoAssets.scene_async(path,get_tree())
			if not scene:continue
			var model:=scene.instantiate() as Node3D
			model.position=Vector3(0,.8,0);model.scale=Vector3.ONE*.5
			if racer.material_albedo:VehicleAssembler.bind_albedo(model,racer.material_name,racer.material_albedo)
			for key in racer.material_bindings:
				if racer.material_bindings[key] is Texture2D:VehicleAssembler.bind_albedo(model,String(key),racer.material_bindings[key])
			showroom.add_child(model)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			model.free()
func build_showroom() -> void:
	# Match the active viewport so Godot can precompile the same pipeline variants.
	viewport.msaa_3d=get_tree().root.msaa_3d
	viewport.transparent_bg=false
	$SubViewportContainer.material=null
	camera=Camera3D.new();camera.fov=LeoPreviewArt.FOV;camera.current=true;showroom.add_child(camera)
	var env := WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("0d1621");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("c5d2de");env.environment.ambient_light_energy=.45;env.environment.tonemap_mode=Environment.TONE_MAPPER_ACES;showroom.add_child(env)
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color=Color("718c9b");sky_mat.sky_horizon_color=Color("e8c492")
	sky_mat.ground_bottom_color=Color("302b24");sky_mat.ground_horizon_color=Color("bba27b")
	sky.sky_material=sky_mat
	env.environment.sky=sky
	env.environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	env.environment.glow_enabled=RenderingServer.get_current_rendering_method()=="forward_plus"
	env.environment.glow_intensity=.65;env.environment.glow_bloom=.08
	for entry in [[Vector3(-4,6,-4),Color("ffe9cc"),2.6],[Vector3(4,4,1),Color("b4d0da"),1.5],[Vector3(0,5,4),Color("ffbe76"),1.9]]:
		var light := OmniLight3D.new();light.position=entry[0];light.light_color=entry[1];light.light_energy=entry[2];light.omni_range=20;showroom.add_child(light)
	var floor:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(26,26);floor.mesh=plane;floor.position.y=-.025
	var floor_material:=ShaderMaterial.new();floor_material.shader=preload("res://shaders/showroom_floor.gdshader");floor.material_override=floor_material;showroom.add_child(floor)
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("141b32");mat.metallic=.28;mat.roughness=.43
	var wall:=StandardMaterial3D.new();wall.albedo_color=Color("15232e");wall.roughness=.88
	LeoRaceVisuals.mesh_box(showroom,Vector3(27,13,.3),Vector3(0,4.8,9.3),wall)
	var screen:=MeshInstance3D.new();screen.name="ColomboBackdropScreen";var screen_mesh:=QuadMesh.new();screen_mesh.size=Vector2(23,10.5);screen.mesh=screen_mesh;screen.position=Vector3(0,4.4,9.1);screen.rotation.y=PI;screen.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var display:=StandardMaterial3D.new();display.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;display.albedo_texture=preload("res://assets/ui/art/garage-skyline-v26.png");display.albedo_color=Color(.8,.86,.94);fit_screen_texture(display,screen_mesh.size);screen.material_override=display;showroom.add_child(screen)
	var platform:=MeshInstance3D.new();platform.name="VehicleDisplayPlatform";var cylinder:=CylinderMesh.new();cylinder.top_radius=3.45;cylinder.bottom_radius=3.55;cylinder.height=.25;cylinder.radial_segments=96;platform.mesh=cylinder;platform.position.y=-.14;platform.material_override=mat;showroom.add_child(platform)
	for entry in [[3.40,Color("62dbe2")],[3.52,Color("e3bc6d")]]:
		var ring:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=entry[0]-.025;torus.outer_radius=entry[0]+.025;torus.rings=96;torus.ring_segments=8;ring.mesh=torus;ring.position.y=-.012
		var emissive:=StandardMaterial3D.new();emissive.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;emissive.albedo_color=entry[1];emissive.emission_enabled=true;emissive.emission=entry[1];emissive.emission_energy_multiplier=1.1;ring.material_override=emissive;ring_materials.append(emissive);showroom.add_child(ring)
	for entry in [[-6.8,Color("49e7ff")],[6.8,Color("c96aff")]]:
		var x: float=entry[0];var tint: Color=entry[1]
		LeoRaceVisuals.mesh_box(showroom,Vector3(.22,7.5,.3),Vector3(x,3.75,6.5),mat)
		showroom_light_bar(Vector3(.10,6.6,.08),Vector3(x,3.55,6.28),tint)
		showroom_light_bar(Vector3(.08,.06,6.0),Vector3(x*.65,4.7,1.0),tint)
		var accent:=OmniLight3D.new();accent.position=Vector3(x*.55,1.8,1.8);accent.light_color=tint;accent.light_energy=.9;accent.omni_range=7.;showroom.add_child(accent)
	for z in [-3.8,3.8]:
		showroom_light_bar(Vector3(11,.025,.045),Vector3(0,-.006,z),Color("58cfff") if z<0 else Color("b66cff"))
	showroom_light_bar(Vector3(22,.08,.08),Vector3(0,9.68,9.),Color("b171ff"))
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-30,0);sun.light_energy=.35;sun.shadow_enabled=true;sun.directional_shadow_max_distance=20.;showroom.add_child(sun)

	reset_view()

func fit_screen_texture(material: StandardMaterial3D,extent: Vector2) -> void:
	var ratio:=material.albedo_texture.get_size().aspect()/extent.aspect()
	var coverage:=Vector2(1.,ratio) if ratio<1. else Vector2(1./ratio,1.)
	material.uv1_scale=Vector3(coverage.x,coverage.y,1.)
	material.uv1_offset=Vector3((1.-coverage.x)*.5,(1.-coverage.y)*.5,0.)

func show_problem(message: String) -> void:
	policy.position=Vector2(390,148);policy.size=Vector2(820,62)
	policy.add_theme_font_size_override("font_size",24);policy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	policy.modulate=Color("ffc857");policy.text=message;policy.show()

func showroom_light_bar(extent: Vector3,at: Vector3,tint: Color) -> void:
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=tint;material.emission_enabled=true;material.emission=tint;material.emission_energy_multiplier=1.35
	var bar:=LeoRaceVisuals.mesh_box(showroom,extent,at,material);bar.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func pulse_rings() -> void:
	if ring_tween:ring_tween.kill()
	var audio:=get_tree().get_first_node_in_group("ui_audio")
	if audio and (is_visible_in_tree() or home_preview):audio.cue("preview")
	if reduced_motion or ring_materials.is_empty():return
	ring_tween=create_tween().set_parallel(true)
	for material in ring_materials:
		material.emission_energy_multiplier=1.7
		material.albedo_color=material.emission*1.35
		ring_tween.tween_property(material,"emission_energy_multiplier",1.1,.2)
		ring_tween.tween_property(material,"albedo_color",material.emission,.2)
func set_reduced_motion(value: bool) -> void:
	reduced_motion=value
	if value:showroom_parallax=Vector2.ZERO;update_camera()
	if carousel:carousel.fx_set_reduced(value)
	for bar in stat_bars:bar.fx_set_reduced(value)
	if value and ring_tween:ring_tween.kill()
	for material in ring_materials:material.emission_energy_multiplier=1.1;material.albedo_color=material.emission

func capture_art(hero_path: String,card_path: String) -> Error:
	if capture_busy or not is_instance_valid(assembly):return ERR_BUSY
	capture_busy=true
	var generation:=selection_generation
	var image:=await LeoPreviewArt.capture_model(showroom,viewport,get_tree())
	capture_busy=false
	if generation!=selection_generation:return ERR_SKIP
	return LeoPreviewArt.save(image,hero_path,card_path)
