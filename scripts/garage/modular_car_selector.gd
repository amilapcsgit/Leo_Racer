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
var driver_buttons: Array[Button] = []
var ui: Control
var title: Label
var machine: Label
var identity: Label
var stats: Label
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
var font: Font = preload("res://assets/fonts/heading.ttf")
@onready var showroom: Node3D = $SubViewportContainer/SubViewport/Garage3D
@onready var viewport: SubViewport = $SubViewportContainer/SubViewport

func _ready() -> void:
	if not catalog: catalog=GarageCatalog.shared()
	var surround := ColorRect.new()
	surround.position=Vector2(-2000,0);surround.size=Vector2(5600,900)
	surround.color=Color("17140f");surround.mouse_filter=MOUSE_FILTER_IGNORE;add_child(surround);move_child(surround,0)
	var background := TextureRect.new()
	background.texture=preload("res://assets/art/garage/workshop.png")
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

func panel(parent: Node, rect: Rect2) -> Panel:
	var backing := ColorRect.new()
	backing.color=Color(.055,.05,.045,.95 if rect.size.x<650 else .86)
	var carbon := ShaderMaterial.new();carbon.shader=preload("res://shaders/garage_carbon.gdshader");backing.material=carbon
	backing.position=rect.position;backing.size=rect.size;backing.mouse_filter=MOUSE_FILTER_IGNORE;parent.add_child(backing)
	var node := Panel.new()
	var frame := StyleBoxTexture.new()
	frame.texture=kit(Rect2(0,0,512,256))
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:frame.set_texture_margin(side,16)
	node.add_theme_stylebox_override("panel",frame)
	node.position=rect.position;node.size=rect.size
	node.mouse_filter=MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

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

func button(parent: Node, words: String, action: Callable, selected:=false) -> Button:
	var node := Button.new()
	node.text=words
	node.add_theme_font_override("font",font)
	node.add_theme_font_size_override("font_size",22)
	node.add_theme_color_override("font_color",cream)
	for state in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color=Color("4a3624") if selected else Color("211e1bec")
		style.border_color=cyan if state=="focus" else (brass if selected or state!="normal" else Color("70604b"))
		style.set_border_width_all(2 if selected or state=="focus" else 1)
		style.set_corner_radius_all(5)
		style.shadow_color=Color(0,0,0,.5);style.shadow_size=3
		node.add_theme_stylebox_override(state,style)
	parent.add_child(node)
	node.pressed.connect(action)
	return node

func build_interface() -> void:
	# Construct once: selection updates labels/models/styles without destroying
	# focused controls, text composition, scroll position or controller routes.
	if ui:return
	process_mode=Node.PROCESS_MODE_ALWAYS
	ui=Control.new();ui.set_anchors_and_offsets_preset(PRESET_FULL_RECT);ui.mouse_filter=MOUSE_FILTER_IGNORE;add_child(ui)
	panel(ui,Rect2(12,12,630,876))
	positioned_label("ASTRA MOTOR CLUB // COLOMBO 2026",Vector2(36,30),18,brass)
	positioned_label("THE PIT SHOP",Vector2(34,68),52)
	positioned_label("01 / DRIVER SETUP",Vector2(36,142),21,brass)
	name_field=LineEdit.new();name_field.position=Vector2(34,184);name_field.size=Vector2(586,55);name_field.max_length=32;name_field.text=custom_name
	name_field.add_theme_font_override("font",font);name_field.add_theme_font_size_override("font_size",26);ui.add_child(name_field)
	name_field.text_changed.connect(func(value: String):custom_name=value;refresh_labels();name_changed.emit(value))
	var keys:=button(ui,"NAME KEYBOARD  /  A",open_keyboard);keys.position=Vector2(367,248);keys.size=Vector2(253,35);keys.add_theme_font_size_override("font_size",17)
	positioned_label("SELECT YOUR DRIVER",Vector2(36,293),21,brass)
	driver_scroll=ScrollContainer.new();driver_scroll.position=Vector2(34,334);driver_scroll.size=Vector2(586,140);driver_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;driver_scroll.follow_focus=true;ui.add_child(driver_scroll)
	var drivers:=HBoxContainer.new();drivers.add_theme_constant_override("separation",6);driver_scroll.add_child(drivers)
	for d in catalog.drivers:
		var card:=button(drivers,"",func():choose_driver(d.id),d.id==driver_id);card.custom_minimum_size=Vector2(90,128);card.tooltip_text=d.display_name
		add_card_content(card,d.display_name,d.portrait,Vector2(82,88),15 if d.display_name.length()>8 else 17);driver_buttons.append(card)
	caption=positioned_label("",Vector2(36,486),18,Color("bcb3a4"));caption.size=Vector2(580,54);caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var dp:=button(ui,"‹ DRIVER",func():cycle_driver(-1));dp.position=Vector2(34,548);dp.size=Vector2(275,43)
	var dn:=button(ui,"DRIVER ›",func():cycle_driver(1));dn.position=Vector2(325,548);dn.size=Vector2(295,43)
	positioned_label("YOUR COMBO. YOUR COAST.",Vector2(36,626),24,brass)
	positioned_label("LB / RB   CHANGE MACHINE\nSTICK / D-PAD   MOVE FOCUS\nA   SELECT     B   BACK",Vector2(36,674),19,cyan)
	var race_y:=820. if not race_context else 744.
	race_button=button(ui,"CONTINUE RACE  →" if race_context else "LET'S MAKE SOME NOISE  →",func():
		if race_context:continue_requested.emit(driver_id,vehicle_id)
		else:race_requested.emit(driver_id,vehicle_id),true)
	race_button.position=Vector2(34,race_y);race_button.size=Vector2(425,50)
	back_button=button(ui,"BACK",func():back_requested.emit());back_button.position=Vector2(472,820);back_button.size=Vector2(148,50)
	if race_context:
		var fresh:=button(ui,"START NEW RACE",func():race_requested.emit(driver_id,vehicle_id));fresh.position=Vector2(34,820);fresh.size=Vector2(425,50)
	panel(ui,Rect2(668,20,912,110))
	title=positioned_label("",Vector2(694,31),38);title.size=Vector2(860,48);title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;title.clip_text=true
	machine=positioned_label("",Vector2(697,82),26,brass);machine.size=Vector2(765,36);machine.clip_text=true;machine.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	counter=positioned_label("",Vector2(1460,84),22,cyan)
	identity=positioned_label("",Vector2(695,143),18,cyan)
	policy=positioned_label("",Vector2(695,180),16,brass)
	previous_button=button(ui,"‹",func():cycle_vehicle(-1));previous_button.text="";previous_button.icon=preload("res://assets/art/garage/carousel_left.svg");previous_button.tooltip_text="Previous vehicle / LB";previous_button.position=Vector2(671,374);previous_button.size=Vector2(70,138);previous_button.add_theme_font_size_override("font_size",68)
	next_button=button(ui,"›",func():cycle_vehicle(1));next_button.text="";next_button.icon=preload("res://assets/art/garage/carousel_right.svg");next_button.tooltip_text="Next vehicle / RB";next_button.position=Vector2(1496,374);next_button.size=Vector2(70,138);next_button.add_theme_font_size_override("font_size",68)
	panel(ui,Rect2(965,749,615,136))
	stats=positioned_label("",Vector2(990,761),23)
	positioned_label("DRAG TO ORBIT  ·  WHEEL TO ZOOM",Vector2(686,803),17,cream)
	var reset:=button(ui,"RESET VIEW",reset_view);reset.position=Vector2(688,836);reset.size=Vector2(220,40)
	var all: Array[Button]=[];all.append_array(driver_buttons);all.append_array([dp,dn,previous_button,next_button,reset,race_button,back_button,keys])
	for i in all.size():
		all[i].focus_next=all[(i+1)%all.size()].get_path();all[i].focus_previous=all[posmod(i-1,all.size())].get_path()
	for i in driver_buttons.size():
		driver_buttons[i].focus_neighbor_left=driver_buttons[posmod(i-1,driver_buttons.size())].get_path();driver_buttons[i].focus_neighbor_right=driver_buttons[(i+1)%driver_buttons.size()].get_path()
		driver_buttons[i].focus_neighbor_top=name_field.get_path();driver_buttons[i].focus_neighbor_bottom=race_button.get_path()
	name_field.focus_neighbor_bottom=driver_buttons[0].get_path()
	race_button.focus_neighbor_top=driver_buttons[0].get_path();race_button.focus_neighbor_right=back_button.get_path()
	build_keyboard()

func refresh_labels() -> void:
	if not ui:return
	var d:=catalog.driver(driver_id);var v:=catalog.vehicle(vehicle_id)
	title.text=(d.display_name if custom_name.strip_edges().is_empty() else custom_name.strip_edges()).to_upper()
	machine.text=v.display_name.to_upper();counter.text="%02d / %02d"%[catalog.vehicle_index(vehicle_id)+1,catalog.vehicles.size()]
	name_field.placeholder_text="ENTER DRIVER NAME  /  "+d.display_name.to_upper()
	identity.text="%d RACERS × %d MACHINES // YOUR COMBO. YOUR COAST."%[catalog.drivers.size(),catalog.vehicles.size()]
	caption.text=d.tagline
	stats.text="TOP SPEED     %03d KM/H\nCORNER GRIP   %.2f\nLAUNCH POWER  %.1f M/S²"%[roundi(v.max_speed*3.6),v.handling,v.acceleration]
	policy.text="HELMETED SHAVEN LEO // FIXED CABIN DRIVER" if v.driver_policy==VehicleDefinition.DriverPolicy.FIXED else ("IDENTITY + PORTRAIT // DRIVER-FREE BODY" if v.driver_policy==VehicleDefinition.DriverPolicy.IDENTITY_ONLY else "OPEN COCKPIT // LIVE DRIVER")
	for i in driver_buttons.size():
		var card:=driver_buttons[i];var selected:=catalog.drivers[i].id==driver_id
		var style:=card.get_theme_stylebox("normal").duplicate() as StyleBoxFlat;style.bg_color=Color("4a3624") if selected else Color("211e1bec");style.border_color=cyan if selected else Color("70604b");style.set_border_width_all(2 if selected else 1);card.add_theme_stylebox_override("normal",style)

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
	keyboard_original=name_field.text;keyboard_caption.text=name_field.text;keyboard.show();keyboard_first.grab_focus()

func keyboard_append(character: String) -> void:
	if name_field.text.length()<32:name_field.text+=character
	keyboard_sync()

func keyboard_sync() -> void:
	custom_name=name_field.text;keyboard_caption.text=custom_name;refresh_labels()

func close_keyboard(cancelled: bool) -> void:
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
	if is_instance_valid(assembly):showroom.remove_child(assembly);assembly.queue_free()
	assembly=VehicleAssembler.assemble(catalog.vehicle(v),catalog.driver(d));showroom.add_child(assembly)
	base_distance=catalog.vehicle(v).preview_distance;target=catalog.vehicle(v).preview_target
	if changed:reset_view()
	else:update_camera()
	refresh_labels()

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
