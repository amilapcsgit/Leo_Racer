class_name LeoVehicleSetup
extends CanvasLayer
## Portable data editor. Source models are copied only when the user saves.
var game: Node
var source_path := ""
var data: Dictionary={}
var status: Label
var fields: VBoxContainer
var meshes: ItemList
var wheel_choice: OptionButton
var driver_choice: OptionButton
var viewport: SubViewport
var studio: Node3D
var camera: Camera3D
var preview: LeoKart
var source_scene: PackedScene
var collision_hint: MeshInstance3D
var wheel_index := 0
var driver_id := "human"
var spin := false
var steering := false
var yaw := -.6
var elapsed := 0.
var generation := 0
var saving := false
var tested := false
var saved_folder := ""
var source_bounds := AABB()
var trial: LeoKart
var trial_input: LeoPlayerInput
var trial_time := 0.
var trial_start := Vector3.ZERO
var trial_road: MeshInstance3D

func _ready() -> void:
	layer=95;process_mode=Node.PROCESS_MODE_ALWAYS
	var shade:=ColorRect.new();shade.color=Color("091522");shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	var panel:=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.theme=load("res://assets/ui/theme.tres");add_child(panel)
	var margin:=MarginContainer.new()
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,20)
	panel.add_child(margin);var box:=VBoxContainer.new();margin.add_child(box)
	var header:=HBoxContainer.new();box.add_child(header)
	var title:=Label.new();title.text="VEHICLE WORKSHOP";title.add_theme_font_size_override("font_size",34);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	button(header,"Back",func():queue_free()).grab_focus()
	status=Label.new();status.add_theme_font_size_override("font_size",18);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.custom_minimum_size.y=42;status.text="Preparing model…";box.add_child(status)
	var row:=HSplitContainer.new();row.size_flags_vertical=Control.SIZE_EXPAND_FILL;row.split_offset=520;box.add_child(row)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size.x=480;scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(scroll)
	fields=VBoxContainer.new();fields.size_flags_horizontal=Control.SIZE_EXPAND_FILL;fields.add_theme_constant_override("separation",10);scroll.add_child(fields)
	var right:=VBoxContainer.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(right)
	var display:=SubViewportContainer.new();display.stretch=true;display.size_flags_vertical=Control.SIZE_EXPAND_FILL;display.custom_minimum_size=Vector2(350,190);right.add_child(display)
	viewport=SubViewport.new();viewport.own_world_3d=true;viewport.size=Vector2i(900,650);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;display.add_child(viewport)
	display.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			data.preview_distance=clampf(float(data.preview_distance)*(.85 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.15),1.,60.);position_camera()
		if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:yaw-=event.relative.x*.01;position_camera())
	studio=Node3D.new();viewport.add_child(studio)
	camera=Camera3D.new();camera.fov=48;studio.add_child(camera)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-35,0);light.light_energy=1.4;studio.add_child(light)
	var world:=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("112333");world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_color=Color("ccdeef");world.environment.ambient_light_energy=.7;studio.add_child(world)
	var floor_node:=MeshInstance3D.new();var floor_mesh:=PlaneMesh.new();floor_mesh.size=Vector2(250,250);floor_node.mesh=floor_mesh;studio.add_child(floor_node)
	var floor_material:=StandardMaterial3D.new();floor_material.albedo_color=Color("273e4c");floor_node.material_override=floor_material
	var ground:=StaticBody3D.new();var shape:=CollisionShape3D.new();var slab:=BoxShape3D.new();slab.size=Vector3(250,1,250);shape.shape=slab;shape.position.y=-.5;ground.add_child(shape);studio.add_child(ground)
	var controls:=HBoxContainer.new();right.add_child(controls)
	button(controls,"Orbit ◀",func():yaw-=.35;position_camera());button(controls,"Orbit ▶",func():yaw+=.35;position_camera())
	var spin_toggle:=CheckButton.new();spin_toggle.text="Spin";spin_toggle.toggled.connect(func(value):spin=value);controls.add_child(spin_toggle)
	var steer_toggle:=CheckButton.new();steer_toggle.text="Steer";steer_toggle.toggled.connect(func(value):steering=value);controls.add_child(steer_toggle)
	meshes=ItemList.new();meshes.select_mode=ItemList.SELECT_MULTI;meshes.custom_minimum_size.y=100;right.add_child(meshes)
	label(right,"Select nodes above; bind them to the chosen wheel.").add_theme_font_size_override("font_size",16)
	var bind:=HBoxContainer.new();right.add_child(bind)
	button(bind,"Bind rotating",func():bind_selected("rotating"));button(bind,"Bind calipers",func():bind_selected("stationary"));button(bind,"Center pivot",center_pivot)
	var footer:=HBoxContainer.new();box.add_child(footer)
	button(footer,"Validate",validate_report);button(footer,"Private Test Drive",test_drive);button(footer,"Finish Test Drive",end_trial);button(footer,"Save Vehicle Folder",save_vehicle)
	if not source_path.is_empty():await load_model()

func configure(vehicle: VehicleDefinition=null,path: String="") -> void:
	if vehicle:
		source_path=vehicle.model_path;data=LeoVehicleCodec.serialize(vehicle)
	else:
		source_path=path
		var temporary:=VehicleDefinition.new();temporary.id=StringName(slug(path.get_file().get_basename()));temporary.display_name=path.get_file().get_basename();temporary.max_speed=165./3.6;temporary.boosted_speed=55.;temporary.setup_complete=true
		data=LeoVehicleCodec.serialize(temporary)
	if is_node_ready():await load_model()

static func slug(value: String) -> String:
	var pattern:=RegEx.new();pattern.compile("[^a-z0-9_.-]")
	var result:=pattern.sub(value.to_lower(),"_",true).trim_prefix("_")
	return ("vehicle_"+result).left(64) if result.is_empty() or not result.substr(0,1).is_valid_identifier() else result.left(64)

func button(parent: Node,words: String,action: Callable) -> Button:
	var node:=Button.new();node.text=words;node.custom_minimum_size=Vector2(130,46);node.pressed.connect(action);parent.add_child(node);return node
func label(parent: Node,words: String) -> Label:
	var node:=Label.new();node.text=words;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(node);return node
func heading(words: String) -> void:
	var node:=label(fields,words);node.add_theme_font_size_override("font_size",24);node.modulate=Color("43e7ef")
func text_field(words: String,value: String,changed: Callable) -> void:
	label(fields,words);var edit:=LineEdit.new();edit.text=value;edit.text_changed.connect(changed);fields.add_child(edit)
func number(parent: Node,value: float,changed: Callable,minimum: float=-1000.,maximum: float=1000.,step: float=.01) -> SpinBox:
	var edit:=SpinBox.new();edit.min_value=minimum;edit.max_value=maximum;edit.step=step;edit.value=value;edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL;edit.value_changed.connect(changed);parent.add_child(edit);return edit
func scalar(words: String,key: String,factor: float=1.,minimum: float=0.01,maximum: float=1000.) -> void:
	label(fields,words);number(fields,float(data.get(key,0))*factor,func(value):data[key]=value/factor;changed(),minimum,maximum)
func vector_field(parent: Node,words: String,value: Array,changed_value: Callable) -> void:
	label(parent,words+" · X / Y / Z");var row:=HBoxContainer.new();parent.add_child(row)
	for i in 3:
		number(row,float(value[i]),func(n):var copy:=value.duplicate();copy[i]=n;value[i]=n;changed_value.call(copy))
func changed() -> void:
	if is_instance_valid(trial):end_trial()
	tested=false;saved_folder="";refresh_preview.call_deferred()

func load_model() -> void:
	status.text="Importing "+source_path.get_file()+"…";await get_tree().process_frame
	source_scene=await LeoAssets.scene_async(source_path,get_tree())
	if not source_scene:status.text=LeoAssets.failure;return
	var model:=source_scene.instantiate() as Node3D;studio.add_child(model)
	source_bounds=bounds(model)
	meshes.clear()
	for child in model.find_children("*","Node3D",true,false):
		meshes.add_item(String(model.get_path_to(child)))
	model.free()
	if data.wheels.is_empty():
		data.collision_size=LeoVehicleCodec.encode(source_bounds.size.max(Vector3(.2,.2,.2)))
		data.collision_position=LeoVehicleCodec.encode(source_bounds.get_center())
		data.preview_target=LeoVehicleCodec.encode(source_bounds.get_center());data.preview_distance=maxf(6.,source_bounds.size.length()*1.3)
		var seat: Dictionary=data.seat;seat.origin=[0,source_bounds.size.y*.55,0]
	build_fields();await refresh_preview()
	status.text="Confirm orientation, wheel groups, pivots, collision and seating. Save creates a portable folder; the original GLB is retained."

func build_fields() -> void:
	for child in fields.get_children():fields.remove_child(child);child.queue_free()
	heading("Identity")
	text_field("Stable ID",String(data.id),func(value):data.id=value;tested=false)
	text_field("Display name",String(data.display_name),func(value):data.display_name=value)
	text_field("Content version",String(data.version),func(value):data.version=value;tested=false)
	text_field("Attribution / license",String(data.get("attribution","")),func(value):data.attribution=value)
	heading("Orientation and scale")
	var transform:=LeoVehicleCodec.transform(data.normalization)
	vector_field(fields,"Rotation degrees",LeoVehicleCodec.encode(transform.basis.get_euler()*180./PI),func(value):
		var t:=LeoVehicleCodec.transform(data.normalization);t.basis=Basis.from_euler(LeoVehicleCodec.vector(value)*PI/180.).scaled(t.basis.get_scale());data.normalization=LeoVehicleCodec.encode(t);changed())
	label(fields,"Uniform model scale")
	number(fields,transform.basis.get_scale().x,func(value):set_model_scale(value),.01,20.)
	button(fields,"Ground model",ground_model)
	heading("Wheels")
	wheel_choice=OptionButton.new();fields.add_child(wheel_choice)
	for i in data.wheels.size():wheel_choice.add_item("Wheel %d · %s"%[i+1,", ".join(data.wheels[i].rotating)])
	wheel_index=clampi(wheel_index,0,maxi(0,data.wheels.size()-1));wheel_choice.select(wheel_index)
	wheel_choice.item_selected.connect(func(index):wheel_index=index;build_fields())
	var row:=HBoxContainer.new();fields.add_child(row)
	button(row,"Add wheel",func():data.wheels.append({"rotating":[],"stationary":[],"pivot":[0,0,0],"axle":[1,0,0],"radius":.4,"steering":false});wheel_index=data.wheels.size()-1;build_fields())
	button(row,"Remove wheel",func():if not data.wheels.is_empty():data.wheels.remove_at(wheel_index);build_fields();changed())
	if not data.wheels.is_empty():
		var wheel: Dictionary=data.wheels[wheel_index]
		label(fields,"Rotating: "+", ".join(wheel.rotating)+"\nStationary: "+", ".join(wheel.stationary))
		vector_field(fields,"Pivot in model space",wheel.pivot,func(value):wheel.pivot=value;changed())
		vector_field(fields,"Unit rotation axle",wheel.axle,func(value):wheel.axle=value;changed())
		label(fields,"Rolling radius (m)");number(fields,float(wheel.radius),func(value):wheel.radius=value;changed(),.02,3.)
		var steer:=CheckButton.new();steer.text="This wheel steers";steer.button_pressed=bool(wheel.steering);steer.toggled.connect(func(value):wheel.steering=value;changed());fields.add_child(steer)
	var hover:=CheckButton.new();hover.text="Hover vehicle (no rotating wheels required)";hover.button_pressed=bool(data.hovering);hover.toggled.connect(func(value):data.hovering=value;changed());fields.add_child(hover)
	heading("Collision")
	vector_field(fields,"Box dimensions (m)",data.collision_size,func(value):data.collision_size=value;changed())
	vector_field(fields,"Box center",data.collision_position,func(value):data.collision_position=value;changed())
	button(fields,"Fit collision to model",fit_collision)
	heading("Driver seating")
	var policy:=OptionButton.new();fields.add_child(policy)
	for words in ["Open seated driver","Identity only / body includes driver","Fixed driver","Cabin pose"]:policy.add_item(words)
	policy.select(int(data.driver_policy));policy.item_selected.connect(func(index):
		data.driver_policy=index
		if index==2:data.fixed_driver_id=driver_id
		changed())
	driver_choice=OptionButton.new();fields.add_child(driver_choice)
	var drivers:=GarageCatalog.shared().drivers
	for driver in drivers:driver_choice.add_item(driver.display_name);driver_choice.set_item_metadata(driver_choice.item_count-1,String(driver.id))
	for i in driver_choice.item_count:
		if driver_choice.get_item_metadata(i)==driver_id:driver_choice.select(i)
	driver_choice.item_selected.connect(func(index):driver_id=String(driver_choice.get_item_metadata(index));build_fields();changed())
	var fit: Dictionary=data.driver_fits.get(driver_id,data.seat).duplicate(true)
	vector_field(fields,"Seat for selected driver",fit.origin,func(value):fit.origin=value;data.driver_fits[driver_id]=fit;changed())
	vector_field(fields,"Driver scale",LeoVehicleCodec.encode(LeoVehicleCodec.transform(fit).basis.get_scale()),func(value):var t:=LeoVehicleCodec.transform(fit);t.basis=t.basis.orthonormalized().scaled(LeoVehicleCodec.vector(value));fit=LeoVehicleCodec.encode(t);data.driver_fits[driver_id]=fit;changed())
	button(fields,"Use this fit for all drivers",func():for driver in drivers:data.driver_fits[String(driver.id)]=fit.duplicate(true);changed())
	heading("Camera and performance")
	vector_field(fields,"Preview camera target",data.preview_target,func(value):data.preview_target=value;changed())
	scalar("Preview distance (m)","preview_distance",1.,1.,60.)
	scalar("Top speed (km/h)","max_speed",3.6,1.,360.)
	scalar("Boost speed (km/h)","boosted_speed",3.6,1.,450.)
	scalar("Acceleration (m/s²)","acceleration",1.,.1,60.)
	scalar("Handling multiplier","handling",1.,.1,3.)
	scalar("Driving camera height offset","camera_height",1.,-2.,5.)
	label(fields,"Custom content and tuning cannot set official records.")

func candidate() -> VehicleDefinition:
	var vehicle:=LeoVehicleCodec.deserialize(data,source_path.get_base_dir());vehicle.model_path=source_path;vehicle.official=false;return vehicle

func bounds(model: Node3D,paths: PackedStringArray=PackedStringArray()) -> AABB:
	var result:=AABB();var found:=false
	for child in model.find_children("*","MeshInstance3D",true,false):
		if not paths.is_empty() and not Array(paths).any(func(path):return String(model.get_path_to(child)).begins_with(path)):continue
		var box: AABB=model.global_transform.affine_inverse()*child.global_transform*child.get_aabb()
		result=result.merge(box) if found else box;found=true
	return result

func refresh_preview() -> void:
	if not source_scene or not is_inside_tree():return
	generation+=1
	if is_instance_valid(preview):preview.free()
	var vehicle:=candidate();var driver:=GarageCatalog.shared().driver(StringName(driver_id))
	if not driver:return
	preview=LeoKart.new();studio.add_child(preview);preview.set_process(false);preview.set_physics_process(false);preview.definition=vehicle
	var body:=VehicleAssembler.assemble(vehicle,driver);preview.add_child(body);preview.visual=body;preview.chassis=body.get_node("Chassis")
	for wheel in vehicle.wheels:
		if wheel.rotating_groups.all(func(path):return VehicleAssembler.find_group(preview.chassis,path)!=null):preview.attach_binding(wheel)
	collision_hint=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=vehicle.collision_size.max(Vector3(.01,.01,.01));collision_hint.mesh=mesh;collision_hint.position=vehicle.collision_position;preview.add_child(collision_hint)
	var material:=StandardMaterial3D.new();material.albedo_color=Color(0.1,1.,1.,.12);material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.cull_mode=BaseMaterial3D.CULL_DISABLED;collision_hint.material_override=material
	position_camera()

func position_camera() -> void:
	var target:=LeoVehicleCodec.vector(data.get("preview_target",[0,1,0]));var distance:=maxf(2.,float(data.get("preview_distance",8.)))
	camera.position=target+Vector3(sin(yaw)*distance,distance*.38,cos(yaw)*distance);camera.look_at(target)

func bind_selected(key: String) -> void:
	if data.wheels.is_empty():status.text="Add a wheel first.";return
	var paths: Array=[]
	for index in meshes.get_selected_items():paths.append(meshes.get_item_text(index))
	data.wheels[wheel_index][key]=paths;build_fields();changed()
func center_pivot() -> void:
	if data.wheels.is_empty():return
	var model:=source_scene.instantiate() as Node3D;studio.add_child(model)
	var box:=bounds(model,PackedStringArray(data.wheels[wheel_index].rotating));model.free()
	data.wheels[wheel_index].pivot=LeoVehicleCodec.encode(box.get_center());build_fields();changed()
func fit_collision() -> void:
	var box: AABB=LeoVehicleCodec.transform(data.normalization)*source_bounds
	data.collision_size=LeoVehicleCodec.encode(box.size);data.collision_position=LeoVehicleCodec.encode(box.get_center());build_fields();changed()
func ground_model() -> void:
	var t:=LeoVehicleCodec.transform(data.normalization);var box: AABB=t*source_bounds;t.origin.y-=box.position.y;data.normalization=LeoVehicleCodec.encode(t);fit_collision()
func set_model_scale(value: float) -> void:
	var t:=LeoVehicleCodec.transform(data.normalization);var ratio:=value/maxf(.001,t.basis.get_scale().x);t.basis=t.basis.orthonormalized().scaled(Vector3.ONE*value);t.origin*=ratio;data.normalization=LeoVehicleCodec.encode(t)
	for key in ["collision_size","collision_position","preview_target"]:data[key]=LeoVehicleCodec.encode(LeoVehicleCodec.vector(data[key])*ratio)
	data.preview_distance=float(data.preview_distance)*ratio
	for wheel in data.wheels:wheel.radius=float(wheel.radius)*ratio
	for driver in data.driver_fits:
		var fit:=LeoVehicleCodec.transform(data.driver_fits[driver]);fit.origin*=ratio;fit.basis=fit.basis.scaled(Vector3.ONE*ratio);data.driver_fits[driver]=LeoVehicleCodec.encode(fit)
	var seat:=LeoVehicleCodec.transform(data.seat);seat.origin*=ratio;seat.basis=seat.basis.scaled(Vector3.ONE*ratio);data.seat=LeoVehicleCodec.encode(seat)
	for i in data.exhausts.size():data.exhausts[i]=LeoVehicleCodec.encode(LeoVehicleCodec.vector(data.exhausts[i])*ratio)
	changed()

func validation() -> PackedStringArray:
	var result:=LeoVehicleLibrary.problems(data,"",false)
	if not source_scene:result.append("Model could not be loaded");return result
	if not result.is_empty():return result
	var model:=source_scene.instantiate() as Node3D
	var claimed: Dictionary={}
	for wheel in data.wheels:
		for path in wheel.rotating+wheel.stationary:
			if not VehicleAssembler.find_group(model,NodePath(path)):result.append("Missing wheel group: "+path)
			if claimed.has(path):result.append("Wheel group bound more than once: "+path)
			for other in claimed:
				if String(path).begins_with(String(other)+"/") or String(other).begins_with(String(path)+"/"):result.append("Overlapping wheel groups: "+path)
			claimed[path]=true
	model.free();return result
func validate_report() -> void:
	var errors:=validation();status.text="Validation passed. Check wheel motion and all driver fits, then use Private Test Drive." if errors.is_empty() else "; ".join(errors)
func test_drive() -> void:
	var errors:=validation()
	if not errors.is_empty():status.text="; ".join(errors);return
	if is_instance_valid(trial):return
	var route:=LeoTrackDefinition.new();var points: Array=[]
	for i in 128:
		var angle:=TAU*float(i)/128.;points.append([50.*cos(angle),0.,50.*sin(angle)])
	route.route={"points":points,"length":TAU*50.,"width":18.}
	var circuit:=LeoCircuit.new(route)
	# setup normally resolves catalog IDs. Temporarily register only this editor
	# definition during setup, never change a race roster or persistent selection.
	var vehicle:=candidate();vehicle.id=&"workshop_trial"
	var catalog:=GarageCatalog.shared();catalog.vehicles.append(vehicle)
	trial=LeoKart.new();studio.add_child(trial);trial.setup(circuit,0,true,driver_id,String(vehicle.id));catalog.vehicles.erase(vehicle)
	trial_time=0.;trial_start=circuit.sample(0)
	trial_input=LeoPlayerInput.new();trial_input.restore(game.input_router.players[0].serialize());trial_input.device=game.input_router.players[0].device
	trial.control_input=trial_input;trial.active=true;trial.place(0,0);LeoRaceRules.apply(trial)
	preview.hide();trial_road=MeshInstance3D.new();var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size():
		var a:=circuit.sample(i*circuit.step,-9.);var b:=circuit.sample(i*circuit.step,9.);var c:=circuit.sample((i+1)*circuit.step,-9.);var d:=circuit.sample((i+1)*circuit.step,9.)
		for vertex in [a,c,b,b,c,d]:surface.set_normal(Vector3.UP);surface.add_vertex(vertex+Vector3.UP*.015)
	trial_road.mesh=surface.commit();var material:=StandardMaterial3D.new();material.albedo_color=Color("273a43");material.cull_mode=BaseMaterial3D.CULL_DISABLED;trial_road.material_override=material;studio.add_child(trial_road)
	status.text="PRIVATE TEST / current P1 controls. Drive, steer and brake. Escape or Finish Test Drive returns here. No settings or records are written."
func end_trial() -> void:
	if not is_instance_valid(trial):return
	tested=trial_time>=1. and trial.position.distance_to(trial_start)>1.
	trial.stop_audio();trial.free();trial=null;trial_input=null
	if is_instance_valid(trial_road):trial_road.free()
	preview.show();position_camera();status.text="Test completed. Save Vehicle Folder exports this configuration." if tested else "Drive at least a metre before finishing the private test."
func save_vehicle() -> void:
	if saving:return
	var errors:=validation()
	if not errors.is_empty():status.text="; ".join(errors);return
	if not tested:status.text="Use Private Test Drive before saving this configuration.";return
	saving=true
	var folder:=LeoVehicleLibrary.default_root().path_join(String(data.id));var destination:=folder.path_join("model.glb")
	if FileAccess.file_exists(folder.path_join("vehicle.json")) and source_path.simplify_path()!=destination.simplify_path():status.text="This ID already belongs to another vehicle. Choose a unique ID.";saving=false;return
	if DirAccess.make_dir_recursive_absolute(folder)!=OK:status.text="Cannot create vehicle folder. Choose a writable game installation.";saving=false;return
	if source_path.simplify_path()!=destination.simplify_path():
		if DirAccess.copy_absolute(source_path,destination)!=OK:status.text="Cannot copy model.";saving=false;return
	var temporary:=folder.path_join("vehicle.json.tmp");var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if not file:status.text="Cannot save vehicle definition.";saving=false;return
	file.store_string(JSON.stringify(data,"  ")+"\n");file.close()
	if DirAccess.rename_absolute(temporary,folder.path_join("vehicle.json"))!=OK:status.text="Cannot replace vehicle definition.";saving=false;return
	if not FileAccess.file_exists(folder.path_join("LICENSE.txt")):FileAccess.open(folder.path_join("LICENSE.txt"),FileAccess.WRITE).store_string(String(data.get("attribution","Author must supply redistribution terms."))+"\n")
	collision_hint.hide();await get_tree().process_frame;await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(folder.path_join("thumbnail.png"));collision_hint.show()
	saved_folder=folder;saving=false;status.text="Saved "+String(data.id)+". Back → Refresh Content makes it selectable. Share this complete folder."

func _process(dt: float) -> void:
	if not visible or not is_instance_valid(preview):return
	if is_instance_valid(trial):
		trial_time+=dt;var target:=trial.position+Vector3.UP*1.2
		camera.position=camera.position.lerp(target+trial.global_basis.z*9.+Vector3.UP*4.,1.-exp(-dt*8.));camera.look_at(target);return
	elapsed+=dt;preview.wheel_motion_speed=5. if spin else 0.;preview.steer=sin(elapsed*1.5) if steering else 0.;preview.animate_wheels(dt)

func _input(event: InputEvent) -> void:
	if not visible:return
	if not is_instance_valid(trial):
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:queue_free();get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:end_trial();get_viewport().set_input_as_handled();return
	for action in trial_input.feed(event):
		if action=="recover":trial.recover()
		if action=="pause_race":end_trial()
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:get_viewport().set_input_as_handled()
