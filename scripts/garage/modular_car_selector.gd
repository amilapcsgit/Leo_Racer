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
var loading_preview: TextureRect
var loading_caption: Label
var warm_only := false
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
	if not warm_only:set_selection(driver_id,vehicle_id)
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
	node.text=words;node.sound_key="back" if words=="Back" else "select";node.primary=selected;node.reduced_motion=reduced_motion;node.pressed.connect(action);parent.add_child(node);node.custom_minimum_size.y=44
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
	driver_caption=positioned_label(("PLAYER %d · " % (player_slot+1) if player_slot>=0 else "")+"CHOOSE YOUR DRIVER",Vector2(40,260),22,cyan)
	carousel=LeoDriverCarousel.new();carousel.catalog=catalog;carousel.reduced_motion=reduced_motion;carousel.position=Vector2(40,300);carousel.size=Vector2(432,224);ui.add_child(carousel);carousel.driver_selected.connect(choose_driver);driver_buttons=carousel.cards
	caption=positioned_label("",Vector2(40,526),22,Color("b9c7d6"));caption.size=Vector2(432,56);caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for i in 4:
		var caption_label:=positioned_label("",Vector2(40,604+i*44),21,cream);stat_labels.append(caption_label)
		var bar: LeoStatBar=load("res://scenes/ui/StatBar.tscn").instantiate();bar.position=Vector2(268,608+i*44);bar.size=Vector2(200,18);bar.reduced_motion=reduced_motion;ui.add_child(bar);stat_bars.append(bar)
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
	var all: Array[Control]=[name_field,keys,carousel,carousel.left,carousel.right,previous_button,next_button,reset,race_button,back_button]
	for i in all.size():
		all[i].focus_next=all[i].get_path_to(all[(i+1)%all.size()]);all[i].focus_previous=all[i].get_path_to(all[posmod(i-1,all.size())])
	carousel.focus_neighbor_top=carousel.get_path_to(name_field);carousel.focus_neighbor_bottom=carousel.get_path_to(race_button)
	carousel.left.focus_neighbor_right=carousel.left.get_path_to(carousel);carousel.right.focus_neighbor_left=carousel.right.get_path_to(carousel)
	for control in [carousel.left,carousel.right]:control.focus_neighbor_top=control.get_path_to(name_field);control.focus_neighbor_bottom=control.get_path_to(race_button)
	name_field.focus_neighbor_bottom=name_field.get_path_to(carousel)
	race_button.focus_neighbor_top=race_button.get_path_to(carousel);race_button.focus_neighbor_right=race_button.get_path_to(back_button)
	build_keyboard()

func refresh_labels() -> void:
	if driver_caption:driver_caption.text=("PLAYER %d · " % (player_slot+1) if player_slot>=0 else "")+"CHOOSE YOUR DRIVER"
	if not ui:return
	var d:=catalog.driver(driver_id);var v:=catalog.vehicle(vehicle_id)
	title.text=(d.display_name if custom_name.strip_edges().is_empty() else custom_name.strip_edges()).to_upper()
	machine.text=v.display_name.to_upper();counter.text="%02d / %02d"%[catalog.vehicle_index(vehicle_id)+1,catalog.vehicles.size()]
	name_field.placeholder_text="ENTER DRIVER NAME  /  "+d.display_name.to_upper()
	identity.text="%d RACERS × %d MACHINES // YOUR COMBO. YOUR COAST."%[catalog.drivers.size(),catalog.vehicles.size()]
	caption.text=d.tagline
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
	return is_inside_tree() and generation==selection_generation and is_visible_in_tree()

func prefetch_neighbors(generation: int) -> void:
	var index:=catalog.vehicle_index(vehicle_id)
	for offset in [-1,1]:
		if not valid_selection(generation):return
		var next: VehicleDefinition=catalog.vehicles[posmod(index+offset,catalog.vehicles.size())]
		await LeoPreviewStream.request(next,get_tree(),func():return valid_selection(generation),false)

func _exit_tree() -> void:selection_generation+=1

func set_selection(d: StringName,v: StringName) -> void:
	var changed:=vehicle_id!=v
	driver_id=d;vehicle_id=v
	if not is_node_ready():return
	selection_generation+=1
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
		loading_preview=TextureRect.new();loading_preview.position=Vector2(620,230);loading_preview.size=Vector2(800,480);loading_preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;loading_preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;loading_preview.mouse_filter=MOUSE_FILTER_IGNORE;ui.add_child(loading_preview)
		loading_caption=positioned_label("",Vector2(650,700),22,cyan)
	loading_preview.texture=car.thumbnail;loading_preview.show();loading_caption.text="Loading your ride…";loading_caption.show();race_button.disabled=true
	if is_instance_valid(assembly):assembly.hide()
	var current:=func():return valid_selection(generation)
	var preview_scene:=await LeoPreviewStream.request(car,get_tree(),current)
	if not preview_scene:
		if generation==selection_generation:machine.text="PREVIEW UNAVAILABLE / CHECK GAME ASSETS";loading_caption.text="Preview unavailable"
		return
	var driver_path:=racer.cabin_model_path if car.driver_policy==VehicleDefinition.DriverPolicy.CABIN else racer.seated_model_path
	if not current.call():return
	loading_caption.text="Preparing driver…"
	if not driver_path.is_empty() and not await LeoAssets.scene_async(driver_path,get_tree()):
		if generation==selection_generation:machine.text="DRIVER PREVIEW UNAVAILABLE / CHECK GAME ASSETS"
		return
	if generation!=selection_generation or not is_inside_tree():return
	if is_instance_valid(assembly):showroom.remove_child(assembly);assembly.queue_free()
	loading_caption.text="Preparing materials…"
	var prepared:=await VehicleAssembler.assemble_async(car,racer,get_tree(),current,preview_scene)
	if not prepared:return
	if not current.is_valid() or not current.call():prepared.free();return
	assembly=prepared
	if not assembly:return
	showroom.add_child(assembly)
	var presented:=LeoVehiclePresentation.resolve(catalog.vehicle(v))
	base_distance=presented.preview_distance;target=presented.preview_target
	if changed:reset_view()
	else:update_camera()
	var gpu_start:=Time.get_ticks_usec()
	await get_tree().process_frame
	if not current.is_valid() or not current.call():return
	LeoPreviewStream.timings.append({"vehicle":String(v),"stage":"gpu_warm_up","ms":(Time.get_ticks_usec()-gpu_start)/1000.})
	loading_preview.hide();loading_caption.hide();race_button.disabled=false
	LeoPreviewStream.timings.append({"vehicle":String(v),"stage":"first_visible","ms":(Time.get_ticks_usec()-start_time)/1000.})
	refresh_labels()
	pulse_rings()
	preview_ready.emit()
	prefetch_neighbors(generation)

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
	if not is_visible_in_tree():selection_generation+=1
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
		var metal:=StandardMaterial3D.new();metal.albedo_color=cyan if radius<3.5 else Color("ffc857");metal.metallic=.7;metal.roughness=.28;metal.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;metal.emission_enabled=true;metal.emission=cyan if radius<3.5 else Color("ffc857");metal.emission_energy_multiplier=1.1;ring_materials.append(metal);rim.material_override=metal;showroom.add_child(rim)
		var halo:=MeshInstance3D.new();var glow_ring:=TorusMesh.new();glow_ring.inner_radius=radius-.06;glow_ring.outer_radius=radius+.10;halo.mesh=glow_ring;halo.position.y=-.035;halo.scale.y=.05
		var glow:=ShaderMaterial.new();glow.shader=preload("res://shaders/garage_ring_halo.gdshader");glow.set_shader_parameter("tint",metal.emission);halo.material_override=glow;showroom.add_child(halo)
	for i in 16:
		var bolt:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=.05;mesh.bottom_radius=.05;mesh.height=.04;mesh.radial_segments=6;bolt.mesh=mesh;bolt.material_override=mat;bolt.position=Vector3(sin(i*TAU/16)*3.52,.015,cos(i*TAU/16)*3.52);showroom.add_child(bolt)

	reset_view()

func pulse_rings() -> void:
	if ring_tween:ring_tween.kill()
	var audio:=get_tree().get_first_node_in_group("ui_audio")
	if audio and is_visible_in_tree():audio.cue("preview")
	if reduced_motion:return
	ring_tween=create_tween().set_parallel(true)
	for material in ring_materials:
		material.emission_energy_multiplier=1.7
		material.albedo_color=material.emission*1.35
		ring_tween.tween_property(material,"emission_energy_multiplier",1.1,.2)
		ring_tween.tween_property(material,"albedo_color",material.emission,.2)
func set_reduced_motion(value: bool) -> void:
	reduced_motion=value
	if carousel:carousel.fx_set_reduced(value)
	for bar in stat_bars:bar.fx_set_reduced(value)
	if value and ring_tween:ring_tween.kill()
	for material in ring_materials:material.emission_energy_multiplier=1.1;material.albedo_color=material.emission
