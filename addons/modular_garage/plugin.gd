@tool
extends EditorPlugin
var dock: VBoxContainer
var file_dialog: EditorFileDialog
var identifier: LineEdit
var display_name: LineEdit
var kind: OptionButton
var status: Label
var draft: Resource
var preview: SubViewport
var last_path := ""

func _enter_tree() -> void:
	dock=VBoxContainer.new();dock.name="Modular Garage"
	var title:=Label.new();title.text="LEO RACER // ASSET ONBOARDING";dock.add_child(title)
	kind=OptionButton.new();kind.add_item("Vehicle GLB");kind.add_item("Driver GLB");dock.add_child(kind)
	identifier=LineEdit.new();identifier.placeholder_text="Stable ID, e.g. coast_coupe";dock.add_child(identifier)
	display_name=LineEdit.new();display_name.placeholder_text="Display name";dock.add_child(display_name)
	var import_button:=Button.new();import_button.text="1. Copy GLB & create draft";import_button.pressed.connect(func():file_dialog.popup_centered_ratio(.7));dock.add_child(import_button)
	var inspect_button:=Button.new();inspect_button.text="2. Inspect / configure selected draft";inspect_button.pressed.connect(edit_draft);dock.add_child(inspect_button)
	var publish_button:=Button.new();publish_button.text="3. Validate, render card & publish";publish_button.pressed.connect(publish_draft);dock.add_child(publish_button)
	var check_button:=Button.new();check_button.text="Validate playable catalog";check_button.pressed.connect(validate_catalog);dock.add_child(check_button)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.custom_minimum_size=Vector2(250,180);status.text="Import into drafts first. In the Inspector set scale/orientation, wheel pivots/radii/axles, collider, seating and camera framing. Then enable setup_complete. Drafts are excluded from exports.";dock.add_child(status)
	file_dialog=EditorFileDialog.new();file_dialog.file_mode=EditorFileDialog.FILE_MODE_OPEN_FILE;file_dialog.access=EditorFileDialog.ACCESS_FILESYSTEM;file_dialog.add_filter("*.glb","Binary glTF");file_dialog.file_selected.connect(import_glb);dock.add_child(file_dialog)
	add_control_to_dock(DOCK_SLOT_RIGHT_BL,dock)

func _exit_tree() -> void:
	remove_control_from_docks(dock);dock.queue_free()

func import_glb(source: String) -> void:
	var id:=identifier.text.strip_edges().to_snake_case().validate_filename()
	if id.is_empty():status.text="Enter a stable ID first.";return
	var catalog:=GarageCatalog.shared()
	if catalog.vehicle(id) or catalog.driver(id):status.text="That stable ID already exists. Choose a new ID.";return
	var directory:="res://assets/models/user/"+id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var target:=directory.path_join(id+".glb")
	if FileAccess.file_exists(target):status.text="Import path already exists. Existing assets will not be overwritten.";return
	var raw:=FileAccess.get_file_as_bytes(source)
	FileAccess.open(target,FileAccess.WRITE).store_buffer(raw)
	var provenance:={"original_filename":source.get_file(),"sha256":FileAccess.get_sha256(source),"author_license":"Review the source GLB asset.extras and record attribution before redistribution."}
	if raw.size()>=20 and raw.decode_u32(0)==0x46546c67:
		var length:=raw.decode_u32(12)
		if 20+length<=raw.size():
			var data=JSON.parse_string(raw.slice(20,20+length).get_string_from_utf8())
			if data is Dictionary:provenance["embedded_asset_metadata"]=data.get("asset",{})
	FileAccess.open(directory.path_join("provenance.json"),FileAccess.WRITE).store_string(JSON.stringify(provenance,"  "))
	get_editor_interface().get_resource_filesystem().scan()
	status.text="Importing copied GLB…"
	await get_tree().create_timer(2.).timeout
	while get_editor_interface().get_resource_filesystem().is_scanning():await get_tree().process_frame
	var scene:=load(target) as PackedScene
	if not scene:status.text="Import failed. Check the Godot Output panel.";return
	if kind.selected==0:
		var vehicle:=VehicleDefinition.new();vehicle.id=id;vehicle.display_name=display_name.text if not display_name.text.is_empty() else id.capitalize();vehicle.model=scene
		vehicle.driver_policy=VehicleDefinition.DriverPolicy.IDENTITY_ONLY
		var model:=scene.instantiate() as Node3D
		dock.add_child(model)
		var wheel_groups: Array[Node3D]=[]
		for node in model.find_children("*","Node3D",true,false):
			var name_lower:=String(node.name).to_lower()
			if ("wheel" in name_lower or "tyre" in name_lower or "tire" in name_lower) and "steering" not in name_lower and "driving" not in name_lower:
				var nested:=false
				for group in wheel_groups:
					if group.is_ancestor_of(node):nested=true
				if not nested:wheel_groups.append(node)
		for group in wheel_groups:
			var binding:=WheelBinding.new();binding.rotating_groups.append(model.get_path_to(group));binding.pivot=(model.global_transform.affine_inverse()*group.global_transform).origin
			binding.steering="front" in String(group.name).to_lower() or "_f" in String(group.name).to_lower()
			vehicle.wheels.append(binding)
		model.queue_free();draft=vehicle
	else:
		var driver:=DriverDefinition.new();driver.id=id;driver.display_name=display_name.text if not display_name.text.is_empty() else id.capitalize();driver.standing_model=scene;driver.seated_model=scene;draft=driver
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/catalog/drafts"))
	last_path="res://assets/catalog/drafts/"+id+".tres"
	ResourceSaver.save(draft,last_path)
	get_editor_interface().get_resource_filesystem().scan()
	edit_draft()
	status.text="Draft created. Auto-detected wheel names are suggestions: inspect pivots, axle direction and each radius. Set the normalization transform, collider and preview framing. Bind all calipers as stationary groups. Driver poses can be separate GLBs. Enable setup_complete only after review."

func edit_draft() -> void:
	var selected:=get_editor_interface().get_inspector().get_edited_object()
	if selected is VehicleDefinition or selected is DriverDefinition:draft=selected
	if draft:get_editor_interface().edit_resource(draft)

func publish_draft() -> void:
	edit_draft()
	if not draft:status.text="Select a draft definition in the FileSystem/Inspector first.";return
	var errors:=PackedStringArray()
	if draft is VehicleDefinition:
		errors=draft.problems()
		var model: Node3D=draft.model.instantiate() if draft.model else null
		if model:
			for w in draft.wheels:
				for path in w.rotating_groups+w.stationary_groups:
					if not VehicleAssembler.find_group(model,path):errors.append("Unresolved group: "+String(path))
			model.free()
	else:
		if draft.id.is_empty() or not draft.seated_model or not draft.standing_model or not draft.setup_complete:errors.append("Driver requires ID, both pose models and completed setup")
	if not errors.is_empty():status.text="Cannot publish:\n"+"\n".join(errors);return
	var catalog:=GarageCatalog.shared()
	if catalog.vehicle(draft.id) or catalog.driver(draft.id):status.text="ID already published. Edit its existing resource instead.";return
	await render_card(draft)
	var destination:="res://assets/catalog/"+("vehicle_" if draft is VehicleDefinition else "driver_")+String(draft.id)+".tres"
	ResourceSaver.save(draft,destination)
	if draft is VehicleDefinition:catalog.vehicles.append(draft)
	else:catalog.drivers.append(draft)
	ResourceSaver.save(catalog,GarageCatalog.PATH)
	get_editor_interface().get_resource_filesystem().scan()
	status.text="Published "+draft.display_name+". The garage, player, AI and future Windows exports use this same catalog automatically."

func render_card(resource: Resource) -> void:
	preview=SubViewport.new();preview.size=Vector2i(512,320);preview.own_world_3d=true;preview.transparent_bg=true;preview.render_target_update_mode=SubViewport.UPDATE_ALWAYS;dock.add_child(preview)
	var world:=Node3D.new();preview.add_child(world)
	var model: Node3D=VehicleAssembler.assemble(resource,GarageCatalog.shared().drivers[0]) if resource is VehicleDefinition else resource.seated_model.instantiate()
	world.add_child(model)
	if resource is DriverDefinition:model.transform=resource.orientation*model.transform
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.9;env.environment.ambient_light_color=Color("c8b6a0");world.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-30,0);light.light_energy=2.;world.add_child(light)
	var camera:=Camera3D.new();world.add_child(camera);camera.current=true;camera.fov=43
	var target: Vector3=resource.preview_target if resource is VehicleDefinition else Vector3(0,.9,0)
	var distance: float=resource.preview_distance if resource is VehicleDefinition else 3.5
	camera.position=target+Vector3(-.6,.35,-1).normalized()*distance;camera.look_at(target)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path:="res://assets/art/garage/thumbnails/"+String(resource.id)+".png"
	preview.get_texture().get_image().save_png(path)
	get_editor_interface().get_resource_filesystem().scan()
	await get_tree().create_timer(.5).timeout
	while get_editor_interface().get_resource_filesystem().is_scanning():await get_tree().process_frame
	if resource is VehicleDefinition:resource.thumbnail=load(path)
	else:resource.portrait=load(path)
	preview.queue_free()

func validate_catalog() -> void:
	var catalog:=GarageCatalog.shared()
	var errors:=catalog.problems()
	status.text="Catalog ready: %d vehicles × %d drivers."%[catalog.vehicles.size(),catalog.drivers.size()] if errors.is_empty() else "\n".join(errors)
