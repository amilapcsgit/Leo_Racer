class_name ModularCarSelector
extends Control
signal selection_changed(driver_id: StringName, vehicle_id: StringName)
signal race_requested(driver_id: StringName, vehicle_id: StringName)
signal back_requested
var catalog: GarageCatalog
var driver_id: StringName = &"hedgehog"
var vehicle_id: StringName = &"blue"
var reduced_motion := false
var assembly: Node3D
var vehicle_page := 0
var driver_page := 0
var driver_buttons: Array[Button] = []
var vehicle_buttons: Array[Button] = []
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
	if ui:
		remove_child(ui);ui.queue_free()
	driver_buttons.clear();vehicle_buttons.clear()
	ui=Control.new();ui.set_anchors_and_offsets_preset(PRESET_FULL_RECT);ui.mouse_filter=MOUSE_FILTER_IGNORE;add_child(ui)
	panel(ui,Rect2(12,12,630,876))
	positioned_label("ASTRA MOTOR CLUB // COLOMBO 2026",Vector2(36,30),18,brass)
	positioned_label("THE PIT SHOP",Vector2(34,68),52)
	positioned_label("01 / PICK YOUR PERSONALITY",Vector2(36,142),21,brass)
	var drivers := HBoxContainer.new();drivers.position=Vector2(34,182);drivers.size=Vector2(586,122);drivers.add_theme_constant_override("separation",6);ui.add_child(drivers)
	for i in range(driver_page*6,mini(driver_page*6+6,catalog.drivers.size())):
		var d := catalog.drivers[i]
		var b := button(drivers,"",func(): choose_driver(d.id),d.id==driver_id)
		b.size_flags_horizontal=SIZE_EXPAND_FILL;b.custom_minimum_size=Vector2(90,122);b.tooltip_text=d.display_name
		add_card_content(b,d.display_name,d.portrait,Vector2(85,78),17)
		driver_buttons.append(b)
	if catalog.drivers.size()>6:
		var next:=button(ui,"RACERS  ›",func(): driver_page=(driver_page+1)%ceili(catalog.drivers.size()/6.);build_interface())
		next.position=Vector2(450,138);next.size=Vector2(170,32)
	positioned_label(catalog.driver(driver_id).tagline,Vector2(36,312),17,Color("bcb3a4"))
	positioned_label("02 / CHOOSE YOUR MACHINE",Vector2(36,362),21,brass)
	var grid := GridContainer.new();grid.columns=3;grid.position=Vector2(34,404);grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);ui.add_child(grid)
	for i in range(vehicle_page*9,mini(vehicle_page*9+9,catalog.vehicles.size())):
		var v := catalog.vehicles[i]
		var b := button(grid,"",func(): choose_vehicle(v.id),v.id==vehicle_id)
		b.custom_minimum_size=Vector2(190,101);b.tooltip_text=v.display_name
		add_card_content(b,v.display_name,v.thumbnail,Vector2(180,62),20)
		vehicle_buttons.append(b)
	var pages := ceili(catalog.vehicles.size()/9.)
	var prev := button(ui,"‹",func(): change_page(-1));prev.position=Vector2(34,738);prev.size=Vector2(62,36)
	positioned_label("MACHINES %02d / %02d"%[vehicle_page+1,pages],Vector2(110,742),19,brass)
	var next := button(ui,"›",func(): change_page(1));next.position=Vector2(306,738);next.size=Vector2(62,36)
	prev.disabled=pages<=1;next.disabled=pages<=1
	positioned_label("ARROWS / STICK SELECT  ·  ENTER / A CONFIRM",Vector2(36,786),16,cyan)
	var race := button(ui,"LET'S MAKE SOME NOISE  →",func(): race_requested.emit(driver_id,vehicle_id),true);race.position=Vector2(34,820);race.size=Vector2(425,50)
	var back := button(ui,"BACK",func(): back_requested.emit());back.position=Vector2(472,820);back.size=Vector2(148,50)
	panel(ui,Rect2(668,20,912,110))
	title=positioned_label(catalog.driver(driver_id).display_name.to_upper(),Vector2(694,31),40)
	machine=positioned_label(catalog.vehicle(vehicle_id).display_name.to_upper(),Vector2(697,82),26,brass)
	identity=positioned_label("%d RACERS × %d MACHINES // YOUR COMBO. YOUR COAST."%[catalog.drivers.size(),catalog.vehicles.size()],Vector2(695,143),18,cyan)
	panel(ui,Rect2(965,749,615,136))
	var v := catalog.vehicle(vehicle_id)
	stats=positioned_label("TOP SPEED     %03d KM/H\nCORNER GRIP   %.2f\nLAUNCH POWER  %.1f M/S²"%[roundi(v.max_speed*3.6),v.handling,v.acceleration],Vector2(990,761),23)
	positioned_label("DRAG TO ORBIT  ·  WHEEL TO ZOOM",Vector2(686,803),17,cream)
	var reset := button(ui,"RESET VIEW",reset_view);reset.position=Vector2(688,836);reset.size=Vector2(220,40)
	positioned_label("IDENTITY + PORTRAIT // DRIVER-FREE BODY" if v.driver_policy==VehicleDefinition.DriverPolicy.IDENTITY_ONLY else "OPEN COCKPIT // LIVE DRIVER",Vector2(695,180),16,brass)
	# Native containers and explicit focus routes remain stable across pagination.
	var all: Array[Button]=[];all.append_array(driver_buttons);all.append_array(vehicle_buttons);all.append_array([prev,next,race,back,reset])
	for i in all.size():
		all[i].focus_next=all[(i+1)%all.size()].get_path();all[i].focus_previous=all[posmod(i-1,all.size())].get_path()
	for i in vehicle_buttons.size():
		var b:=vehicle_buttons[i]
		b.focus_neighbor_top=vehicle_buttons[i-3].get_path() if i>=3 else driver_buttons[mini(i,driver_buttons.size()-1)].get_path()
		b.focus_neighbor_bottom=vehicle_buttons[i+3].get_path() if i+3<vehicle_buttons.size() else race.get_path()
		b.focus_neighbor_left=vehicle_buttons[posmod(i-1,vehicle_buttons.size())].get_path()
		b.focus_neighbor_right=vehicle_buttons[(i+1)%vehicle_buttons.size()].get_path()
	for i in driver_buttons.size():
		driver_buttons[i].focus_neighbor_bottom=vehicle_buttons[mini(i/2,vehicle_buttons.size()-1)].get_path()
		driver_buttons[i].focus_neighbor_top=race.get_path()

func add_card_content(b: Button, name_text: String, texture: Texture2D, image_size: Vector2, fs: int) -> void:
	var box := VBoxContainer.new();box.set_anchors_and_offsets_preset(PRESET_FULL_RECT);box.offset_left=5;box.offset_right=-5;box.offset_top=3;box.offset_bottom=-4;box.mouse_filter=MOUSE_FILTER_IGNORE;b.add_child(box)
	var pic := TextureRect.new();pic.texture=texture;pic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;pic.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;pic.custom_minimum_size=image_size;pic.size_flags_vertical=SIZE_EXPAND_FILL;pic.mouse_filter=MOUSE_FILTER_IGNORE;box.add_child(pic)
	var text := label(box,name_text.to_upper(),fs);text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;text.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;text.clip_text=true;text.custom_minimum_size.x=0

func set_selection(d: StringName,v: StringName) -> void:
	driver_id=d;vehicle_id=v
	if not is_node_ready():return
	vehicle_page=catalog.vehicle_index(v)/9
	driver_page=catalog.driver_index(d)/6
	if is_instance_valid(assembly):showroom.remove_child(assembly);assembly.queue_free()
	assembly=VehicleAssembler.assemble(catalog.vehicle(v),catalog.driver(d));showroom.add_child(assembly)
	base_distance=catalog.vehicle(v).preview_distance;target=catalog.vehicle(v).preview_target
	reset_view();build_interface()

func choose_driver(id: StringName) -> void:
	set_selection(id,vehicle_id);selection_changed.emit(driver_id,vehicle_id)
	driver_buttons[catalog.driver_index(driver_id)%6].grab_focus()

func choose_vehicle(id: StringName) -> void:
	set_selection(driver_id,id);selection_changed.emit(driver_id,vehicle_id)
	vehicle_buttons[catalog.vehicle_index(vehicle_id)%9].grab_focus()

func change_page(direction: int) -> void:
	vehicle_page=posmod(vehicle_page+direction,ceili(catalog.vehicles.size()/9.));build_interface();vehicle_buttons[0].grab_focus()

func reset_view() -> void:
	yaw=-.6;pitch=.24;zoom=1.;idle=0.;update_camera()

func update_camera() -> void:
	if not camera:return
	camera.position=target+Vector3(sin(yaw)*cos(pitch),sin(pitch),-cos(yaw)*cos(pitch))*base_distance*zoom
	camera.look_at(target)

func sync_visibility() -> void:
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	set_process(is_visible_in_tree())

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.position.x>650:
		if event.button_index==MOUSE_BUTTON_LEFT:dragging=event.pressed;accept_event()
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom=clampf(zoom+(-.08 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .08),.65,1.5);idle=0.;update_camera();accept_event()
	if event is InputEventMouseMotion and dragging:
		yaw+=event.relative.x*.008;pitch=clampf(pitch+event.relative.y*.004,.06,.65);idle=0.;update_camera();accept_event()

func _process(dt: float) -> void:
	if get_tree().paused:return
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
