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
var driver_scroll: ScrollContainer
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
var yaw := -.6
var pitch := .24
var zoom := 1.0
var dragging := false
var idle := 0.0
var base_distance := 8.0
var target := Vector3(0,1,0)
var cream := Color("f3e5ca")
var brass := Color("d6b77a")
var cyan := Color("67d6db")
var font: Font = preload("res://assets/fonts/BarlowCondensed-BoldItalic.ttf")
@onready var showroom: Node3D = $SubViewportContainer/SubViewport/Garage3D
@onready var viewport: SubViewport = $SubViewportContainer/SubViewport

func _ready() -> void:
	theme=load("res://assets/ui/theme.tres")
	if not catalog: catalog=GarageCatalog.shared()
	var surround := ColorRect.new()
	surround.position=Vector2(-2000,0);surround.size=Vector2(5600,900)
	surround.color=Color("17140f");surround.mouse_filter=MOUSE_FILTER_IGNORE;add_child(surround);move_child(surround,0)
	var background := TextureRect.new()
	background.texture=preload("res://assets/ui/art/garage.png")
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter=MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background,1)
	build_showroom()
	build_interface()
	set_selection(driver_id,vehicle_id)
	visibility_changed.connect(sync_visibility)
	sync_visibility()

func configure(data: GarageCatalog, d: StringName, v: StringName, reduced: bool) -> void:
	catalog=data;driver_id=d;vehicle_id=v;reduced_motion=reduced

func kit(region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas=preload("res://assets/art/garage/hud_kit.svg")
	atlas.region=region
	return atlas

func panel(parent: Node,rect: Rect2) -> Panel:
	var node:=Panel.new();node.position=rect.position;node.size=rect.size
	var box:=StyleBoxFlat.new();box.bg_color=Color("101722ee");box.border_color=Color("526372");box.set_border_width_all(1);box.set_corner_radius_all(16);box.shadow_color=Color(0,0,0,.5);box.shadow_size=12
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
	var node := label(ui,words,font_size,color);node.position=pos
	return node

func button(parent: Node,words: String,action: Callable,selected:=false) -> Button:
	var node: LeoActionButton=load("res://scenes/ui/ActionButton.tscn").instantiate()
	node.text=words;node.primary=selected;node.reduced_motion=reduced_motion;node.pressed.connect(action);parent.add_child(node);node.custom_minimum_size.y=44
	return node

func build_interface() -> void:
	if ui:return
	process_mode=Node.PROCESS_MODE_ALWAYS
	ui=Control.new();ui.set_anchors_and_offsets_preset(PRESET_FULL_RECT);ui.mouse_filter=MOUSE_FILTER_IGNORE;add_child(ui)
	panel(ui,Rect2(16,20,480,860))
	positioned_label("COLOMBO MOTOR CLUB",Vector2(40,36),20,cyan)
	positioned_label("THE PIT SHOP",Vector2(38,72),48)
	name_field=LineEdit.new();name_field.position=Vector2(40,141);name_field.size=Vector2(432,48);name_field.max_length=32;name_field.text=custom_name;name_field.add_theme_font_size_override("font_size",26);ui.add_child(name_field)
	name_field.text_changed.connect(func(value: String):custom_name=value;refresh_labels();name_changed.emit(value))
	var keys:=button(ui,"Change Name",open_keyboard);keys.position=Vector2(224,201);keys.size=Vector2(248,44)
	positioned_label("CHOOSE YOUR DRIVER",Vector2(40,260),22,cyan)
	driver_scroll=ScrollContainer.new();driver_scroll.position=Vector2(40,300);driver_scroll.size=Vector2(432,152);driver_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;driver_scroll.follow_focus=true;ui.add_child(driver_scroll)
	var portrait_margin:=MarginContainer.new()
	for side in ["left","right","top","bottom"]:portrait_margin.add_theme_constant_override("margin_"+side,8)
	driver_scroll.add_child(portrait_margin)
	var drivers:=HBoxContainer.new();drivers.add_theme_constant_override("separation",12);portrait_margin.add_child(drivers)
	for d in catalog.drivers:
		var card:=button(drivers,"",func():choose_driver(d.id));card.custom_minimum_size=Vector2(112,128);card.tooltip_text=d.display_name
		var frame:=TextureRect.new();frame.texture=preload("res://assets/ui/icons/hex_frame.svg");frame.set_anchors_and_offsets_preset(PRESET_FULL_RECT);frame.mouse_filter=MOUSE_FILTER_IGNORE;frame.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;card.add_child(frame);card.set_meta("portrait_frame",frame)
		add_card_content(card,d.display_name,d.portrait,Vector2(96,96),20);driver_buttons.append(card)
		card.focus_entered.connect(func():animate_portrait(card,true));card.focus_exited.connect(func():animate_portrait(card,false));card.mouse_entered.connect(func():animate_portrait(card,true));card.mouse_exited.connect(func():animate_portrait(card,false))
	caption=positioned_label("",Vector2(40,466),22,Color("b9c7d6"));caption.size=Vector2(432,56);caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var dp:=button(ui,"‹ Driver",func():cycle_driver(-1));dp.position=Vector2(40,534);dp.size=Vector2(210,44)
	var dn:=button(ui,"Driver ›",func():cycle_driver(1));dn.position=Vector2(262,534);dn.size=Vector2(210,44)
	for i in 3:
		var caption_label:=positioned_label("",Vector2(40,604+i*52),21,cream);stat_labels.append(caption_label)
		var bar: LeoStatBar=load("res://scenes/ui/StatBar.tscn").instantiate();bar.position=Vector2(268,608+i*52);bar.size=Vector2(200,18);bar.reduced_motion=reduced_motion;ui.add_child(bar);stat_bars.append(bar)
	positioned_label("Your combo. Your coast.",Vector2(40,770),22,cyan)
	race_button=button(ui,"Keep Racing" if race_context else "Use This Ride",func():
		if race_context:continue_requested.emit(driver_id,vehicle_id)
		else:race_requested.emit(driver_id,vehicle_id),true)
	race_button.position=Vector2(40,812);race_button.size=Vector2(432,48)
	back_button=button(ui,"Back",func():back_requested.emit());back_button.position=Vector2(1328,812);back_button.size=Vector2(224,48)
	panel(ui,Rect2(536,20,1016,108))
	title=positioned_label("",Vector2(560,30),38);title.size=Vector2(910,44);title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;title.clip_text=true
	machine=positioned_label("",Vector2(560,78),28,cyan);machine.size=Vector2(810,40);machine.clip_text=true
	counter=positioned_label("",Vector2(1450,80),22,cyan)
	identity=positioned_label("Your ride. Your rules.",Vector2(558,138),20,cream)
	policy=positioned_label("",Vector2(558,164),20);policy.hide()
	previous_button=button(ui,"‹",func():cycle_vehicle(-1));previous_button.position=Vector2(540,382);previous_button.size=Vector2(64,112);previous_button.tooltip_text="Previous ride · LB"
	next_button=button(ui,"›",func():cycle_vehicle(1));next_button.position=Vector2(1488,382);next_button.size=Vector2(64,112);next_button.tooltip_text="Next ride · RB"
	stats=positioned_label("",Vector2.ZERO,20);stats.hide()
	positioned_label("Drag to orbit · Scroll to zoom · LB / RB change ride",Vector2(560,772),20,cream)
	var reset:=button(ui,"Reset View",reset_view);reset.position=Vector2(560,812);reset.size=Vector2(224,48)
	var all: Array[Button]=[];all.append_array(driver_buttons);all.append_array([dp,dn,previous_button,next_button,reset,race_button,back_button,keys])
	for i in all.size():
		all[i].focus_next=all[i].get_path_to(all[(i+1)%all.size()]);all[i].focus_previous=all[i].get_path_to(all[posmod(i-1,all.size())])
	for i in driver_buttons.size():
		driver_buttons[i].focus_neighbor_left=driver_buttons[i].get_path_to(driver_buttons[posmod(i-1,driver_buttons.size())]);driver_buttons[i].focus_neighbor_right=driver_buttons[i].get_path_to(driver_buttons[(i+1)%driver_buttons.size()])
		driver_buttons[i].focus_neighbor_top=driver_buttons[i].get_path_to(name_field);driver_buttons[i].focus_neighbor_bottom=driver_buttons[i].get_path_to(race_button)
	name_field.focus_neighbor_bottom=name_field.get_path_to(driver_buttons[0])
	race_button.focus_neighbor_top=race_button.get_path_to(driver_buttons[0]);race_button.focus_neighbor_right=race_button.get_path_to(back_button)
	build_keyboard()

func animate_portrait(card: Button,focused: bool) -> void:
	if focused and card is LeoActionButton and not reduced_motion:card.stars()
	if portrait_tweens.has(card):portrait_tweens[card].kill()
	card.pivot_offset=card.size*.5
	var tween:=create_tween();portrait_tweens[card]=tween
	tween.tween_property(card,"scale",Vector2.ONE*(1.10 if focused and not reduced_motion else 1.),.12)

func refresh_labels() -> void:
	if not ui:return
	var d:=catalog.driver(driver_id);var v:=catalog.vehicle(vehicle_id)
	title.text=(d.display_name if custom_name.strip_edges().is_empty() else custom_name.strip_edges()).to_upper()
	machine.text=v.display_name.to_upper();counter.text="%02d / %02d"%[catalog.vehicle_index(vehicle_id)+1,catalog.vehicles.size()]
	name_field.placeholder_text="ENTER DRIVER NAME  /  "+d.display_name.to_upper()
	identity.text="%d RACERS × %d MACHINES // YOUR COMBO. YOUR COAST."%[catalog.drivers.size(),catalog.vehicles.size()]
	caption.text=d.tagline
	stats.text="TOP SPEED     %03d KM/H\nCORNER GRIP   %.2f\nLAUNCH POWER  %.1f M/S²"%[roundi(float(LeoRaceRules.resolve(v).max_speed)*3.6),float(LeoRaceRules.resolve(v).handling),float(LeoRaceRules.resolve(v).acceleration)]
	var rules:=LeoRaceRules.resolve(v)
	var values: Array[float]=[float(rules.max_speed)*3.6,float(rules.handling),float(rules.acceleration)]
	var maxima: Array[float]=[0.,0.,0.]
	for vehicle in catalog.vehicles:
		var resolved:=LeoRaceRules.resolve(vehicle)
		maxima[0]=maxf(maxima[0],float(resolved.max_speed)*3.6);maxima[1]=maxf(maxima[1],float(resolved.handling));maxima[2]=maxf(maxima[2],float(resolved.acceleration))
	for i in 3:
		stat_bars[i].set_value(values[i]/maxf(.001,maxima[i]))
		stat_labels[i].text=["Speed · %d km/h" % roundi(values[0]),"Grip · %.2f" % values[1],"Launch · %.1f m/s²" % values[2]][i]
	policy.text="SELECTED RACER // CABIN POSE" if v.driver_policy==VehicleDefinition.DriverPolicy.CABIN else "HELMETED SHAVEN LEO // FIXED CABIN DRIVER" if v.driver_policy==VehicleDefinition.DriverPolicy.FIXED else ("IDENTITY + PORTRAIT // DRIVER-FREE BODY" if v.driver_policy==VehicleDefinition.DriverPolicy.IDENTITY_ONLY else "OPEN COCKPIT // LIVE DRIVER")
	for i in driver_buttons.size():
		var card:=driver_buttons[i];var selected:=catalog.drivers[i].id==driver_id
		card.modulate=Color.WHITE if selected else Color(.72,.78,.82)
		var frame: TextureRect=card.get_meta("portrait_frame")
		frame.texture=load("res://assets/ui/icons/hex_selected.svg") if selected else load("res://assets/ui/icons/hex_frame.svg")

func cycle_vehicle(direction: int) -> void:
	choose_vehicle(catalog.vehicles[posmod(catalog.vehicle_index(vehicle_id)+direction,catalog.vehicles.size())].id)

func cycle_driver(direction: int) -> void:
	choose_driver(catalog.drivers[posmod(catalog.driver_index(driver_id)+direction,catalog.drivers.size())].id)
	driver_buttons[catalog.driver_index(driver_id)].grab_focus()

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

func set_selection(d: StringName,v: StringName) -> void:
	var changed:=vehicle_id!=v
	driver_id=d;vehicle_id=v
	if not is_node_ready():return
	selection_generation+=1
	var generation:=selection_generation
	var car:=catalog.vehicle(v)
	var racer:=catalog.driver(d)
	refresh_labels()
	if not car.model_path.is_empty() and not await LeoAssets.scene_async(car.model_path,get_tree()):
		if generation==selection_generation:machine.text="PREVIEW UNAVAILABLE / CHECK GAME ASSETS"
		return
	var driver_path:=racer.cabin_model_path if car.driver_policy==VehicleDefinition.DriverPolicy.CABIN else racer.seated_model_path
	if not driver_path.is_empty() and not await LeoAssets.scene_async(driver_path,get_tree()):
		if generation==selection_generation:machine.text="DRIVER PREVIEW UNAVAILABLE / CHECK GAME ASSETS"
		return
	if generation!=selection_generation or not is_inside_tree():return
	if is_instance_valid(assembly):showroom.remove_child(assembly);assembly.queue_free()
	assembly=VehicleAssembler.assemble(catalog.vehicle(v),catalog.driver(d));showroom.add_child(assembly)
	base_distance=catalog.vehicle(v).preview_distance;target=catalog.vehicle(v).preview_target
	if changed:reset_view()
	else:update_camera()
	refresh_labels()
	preview_ready.emit()

func choose_driver(id: StringName) -> void:
	set_selection(id,vehicle_id);selection_changed.emit(driver_id,vehicle_id)

func choose_vehicle(id: StringName) -> void:
	set_selection(driver_id,id);selection_changed.emit(driver_id,vehicle_id)

func reset_view() -> void:
	yaw=-.6;pitch=.24;zoom=1.;idle=0.;update_camera()

func update_camera() -> void:
	if not camera:return
	camera.position=target+Vector3(sin(yaw)*cos(pitch),sin(pitch),-cos(yaw)*cos(pitch))*base_distance*zoom
	camera.look_at(target)

func sync_visibility() -> void:
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	set_process(is_visible_in_tree());set_process_input(is_visible_in_tree())

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.position.x>650:
		if event.button_index==MOUSE_BUTTON_LEFT:dragging=event.pressed;accept_event()
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom=clampf(zoom+(-.08 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .08),.65,1.5);idle=0.;update_camera();accept_event()
	if event is InputEventMouseMotion and dragging:
		yaw+=event.relative.x*.008;pitch=clampf(pitch+event.relative.y*.004,.06,.65);idle=0.;update_camera();accept_event()

func _process(dt: float) -> void:
	if get_tree().paused and not race_context:return
	idle+=dt
	if not reduced_motion and not dragging and idle>4.:yaw+=dt*.12;update_camera()

func build_showroom() -> void:
	camera=Camera3D.new();camera.fov=43;camera.current=true;showroom.add_child(camera)
	var env := WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0,0,0,0);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("c9b69e");env.environment.ambient_light_energy=.7;env.environment.tonemap_mode=Environment.TONE_MAPPER_ACES;showroom.add_child(env)
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color=Color("718c9b");sky_mat.sky_horizon_color=Color("e8c492")
	sky_mat.ground_bottom_color=Color("302b24");sky_mat.ground_horizon_color=Color("bba27b")
	sky.sky_material=sky_mat
	env.environment.sky=sky
	env.environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	for entry in [[Vector3(-4,6,-4),Color("ffe3b9"),3.2],[Vector3(4,4,1),Color("8ebdcc"),2.1],[Vector3(0,5,4),Color("ffbe76"),2.5]]:
		var light := OmniLight3D.new();light.position=entry[0];light.light_color=entry[1];light.light_energy=entry[2];light.omni_range=20;showroom.add_child(light)
	var podium := MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.top_radius=3.6;cylinder.bottom_radius=3.7;cylinder.height=.32;cylinder.radial_segments=80;podium.mesh=cylinder;podium.position.y=-.19
	var mat := StandardMaterial3D.new();mat.albedo_color=Color("272625");mat.metallic=.65;mat.roughness=.34;podium.material_override=mat;showroom.add_child(podium)
	for radius in [3.42,3.62]:
		var rim:=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=radius;ring.outer_radius=radius+.035;rim.mesh=ring;rim.position.y=-.015
		var metal:=StandardMaterial3D.new();metal.albedo_color=brass;metal.metallic=.75;metal.roughness=.26;rim.material_override=metal;showroom.add_child(rim)
	for i in 16:
		var bolt:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=.05;mesh.bottom_radius=.05;mesh.height=.04;mesh.radial_segments=6;bolt.mesh=mesh;bolt.material_override=mat;bolt.position=Vector3(sin(i*TAU/16)*3.52,.015,cos(i*TAU/16)*3.52);showroom.add_child(bolt)
