extends Control
## Offline companion window. Conversion never edits the selected source GLB.
signal completed(result: Dictionary)
const Converter = preload("res://tools/vehicle_workshop/converter.gd")
const NAMES := ["Front left", "Front right", "Rear left", "Rear right"]
var job: Dictionary = {}
var inspection: Dictionary = {}
var converted: Dictionary = {}
var wheel_groups: Array = [[], [], [], []]
var caliper_groups: Array = [[], [], [], []]
var overrides: Array = [{}, {}, {}, {}]
var source := ""
var rotation_value := Vector3.ZERO
var model_scale := 1.0
var grounded := true
var confirmed := false
var busy := false
var generation := 0
var selected_wheel := 0
var elapsed := 0.0
var yaw := .7
var distance := 9.0
var target := Vector3(0, 1, 0)
var status: Label
var source_label: Label
var fields: VBoxContainer
var inventory: ItemList
var wheel_select: OptionButton
var confirm_toggle: CheckButton
var name_edit: LineEdit
var id_edit: LineEdit
var license_edit: LineEdit
var spin_toggle: CheckButton
var steer_toggle: CheckButton
var boost_toggle: CheckButton
var viewport: SubViewport
var studio: Node3D
var camera: Camera3D
var model_root: Node3D
var wheel_preview: LeoKart
var collision_hint: MeshInstance3D
var selection_hint: MeshInstance3D
var flames: Array[Node3D] = []
var file_picker: FileDialog
var folder_picker: FileDialog
var collision_size := Vector3(2, 1.5, 4.5)
var collision_center := Vector3(0, .8, 0)
var save_root := ""
var source_hash := ""
var worker_task := -1
var worker_result: Dictionary = {}
var exporting := false
var boost_anchors: Array = [Vector3(-.4, .4, 2.4), Vector3(.4, .4, 2.4)]
var region_center := Vector3.ZERO
var region_size := Vector3(.9, .9, .9)
var inventory_filter: LineEdit
var collision_toggle: CheckButton
var front_marker: Label3D

func configure(value: Dictionary) -> void:
	job = value.duplicate(true)
	if is_node_ready():
		apply_job()

func _ready() -> void:
	theme=load("res://assets/ui/theme.tres")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("0b1320")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	add_child(margin)
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := label(header, "LEO RACER / CUSTOM CAR WORKSHOP")
	title.add_theme_font_size_override("font_size", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(header, "Back / Close", cancel).grab_focus()
	source_label = label(layout, "Choose a GLB to begin. Fully offline; your source file stays unchanged.")
	status = label(layout, "1. Import  →  2. Confirm four wheels  →  3. Preview  →  4. Install")
	status.custom_minimum_size.y = 42
	status.modulate = Color("60e3e8")
	var splitter := HSplitContainer.new()
	splitter.split_offset = 420
	splitter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(splitter)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 350
	splitter.add_child(scroll)
	fields = VBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("separation", 7)
	scroll.add_child(fields)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	splitter.add_child(right)
	var display := SubViewportContainer.new()
	display.stretch = true
	display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	display.custom_minimum_size = Vector2(330, 180)
	right.add_child(display)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(1000, 700)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	display.add_child(viewport)
	display.gui_input.connect(preview_input)
	studio = Node3D.new()
	viewport.add_child(studio)
	camera = Camera3D.new()
	camera.fov = 48
	studio.add_child(camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("142638")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b9d4ed")
	environment.environment.ambient_light_energy = .8
	studio.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 1.5
	studio.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(250, 250)
	floor_mesh.mesh = plane
	floor_mesh.material_override = material(Color("263b4c"))
	floor_mesh.position.y = -.025
	studio.add_child(floor_mesh)
	front_marker = Label3D.new()
	front_marker.text = "FRONT / -Z"
	front_marker.font_size = 38
	front_marker.pixel_size = .008
	front_marker.modulate = Color("50e4e9")
	front_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	front_marker.no_depth_test = true
	front_marker.position = Vector3(0, .15, -3.5)
	studio.add_child(front_marker)
	var previews := HFlowContainer.new()
	right.add_child(previews)
	spin_toggle = toggle(previews, "Spin wheels", true)
	steer_toggle = toggle(previews, "Steer", false)
	boost_toggle = toggle(previews, "Blue boost", false)
	collision_toggle = toggle(previews, "Collision", false)
	collision_toggle.toggled.connect(func(value): if is_instance_valid(collision_hint): collision_hint.visible = value)
	button(previews, "Reset view", fit_camera)
	label(right, "Drag to orbit · wheel to zoom · select wheel components below")
	inventory_filter = LineEdit.new()
	inventory_filter.placeholder_text = "Filter 1,000+ pieces by island ID, name or wheel/caliper/body…"
	inventory_filter.text_changed.connect(func(_value): populate_inventory())
	right.add_child(inventory_filter)
	inventory = ItemList.new()
	inventory.select_mode = ItemList.SELECT_MULTI
	inventory.custom_minimum_size.y = 145
	inventory.item_selected.connect(func(_index): highlight_selection())
	inventory.multi_selected.connect(func(_index, _selected): highlight_selection())
	right.add_child(inventory)
	var assignment := HFlowContainer.new()
	right.add_child(assignment)
	button(assignment, "Use as wheel", func(): assign_selection(false))
	button(assignment, "Use as caliper", func(): assign_selection(true))
	button(assignment, "Guided region", select_region)
	var footer := HFlowContainer.new()
	layout.add_child(footer)
	button(footer, "Import GLB…", choose_source)
	button(footer, "Apply / Validate", build_preview)
	button(footer, "Private Test Drive", private_test)
	button(footer, "Install Vehicle Folder", install_vehicle)
	file_picker = FileDialog.new()
	file_picker.access = FileDialog.ACCESS_FILESYSTEM
	file_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_picker.use_native_dialog = true
	file_picker.filters = PackedStringArray(["*.glb ; GLB vehicle model"])
	file_picker.file_selected.connect(import_source)
	add_child(file_picker)
	folder_picker = FileDialog.new()
	folder_picker.access = FileDialog.ACCESS_FILESYSTEM
	folder_picker.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	folder_picker.use_native_dialog = true
	folder_picker.dir_selected.connect(func(path): save_root = path; status.text = "Install destination: " + path)
	add_child(folder_picker)
	build_fields()
	apply_job()

func apply_job() -> void:
	save_root = String(job.get("vehicles_root", LeoVehicleLibrary.default_root()))
	var path := String(job.get("source", ""))
	if not path.is_empty(): import_source(path)

func label(parent: Node, text: String) -> Label:
	var control := Label.new()
	control.text = text
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(control)
	return control

func button(parent: Node, text: String, action: Callable) -> Button:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size.y = 48
	control.pressed.connect(action)
	parent.add_child(control)
	return control

func toggle(parent: Node, text: String, enabled: bool) -> CheckButton:
	var control := CheckButton.new()
	control.text = text
	control.button_pressed = enabled
	parent.add_child(control)
	return control

func number(parent: Node, value: float, action: Callable, minimum := -10000., maximum := 10000., step := .01) -> SpinBox:
	var control := SpinBox.new()
	control.min_value = minimum
	control.max_value = maximum
	control.step = step
	control.value = value
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.value_changed.connect(action)
	parent.add_child(control)
	return control

func vector_field(text: String, value: Vector3, action: Callable) -> void:
	label(fields, text + " (X / Y / Z)")
	var row := HBoxContainer.new()
	fields.add_child(row)
	var values: Array = [value.x, value.y, value.z]
	for axis in 3:
		number(row, values[axis], func(v): values[axis] = v; action.call(Vector3(values[0], values[1], values[2])))

func build_fields() -> void:
	var remembered_name := name_edit.text if is_instance_valid(name_edit) else source.get_file().get_basename()
	var remembered_id := id_edit.text if is_instance_valid(id_edit) else LeoVehicleSetup.slug(remembered_name)
	var remembered_license := license_edit.text if is_instance_valid(license_edit) else "Personal import; author must supply redistribution rights."
	for child in fields.get_children():
		fields.remove_child(child)
		child.queue_free()
	label(fields, "IDENTITY / OFFLINE CONTENT")
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Vehicle display name"
	name_edit.text = remembered_name
	fields.add_child(name_edit)
	id_edit = LineEdit.new()
	id_edit.placeholder_text = "unique_vehicle_id"
	id_edit.text = remembered_id
	fields.add_child(id_edit)
	license_edit = LineEdit.new()
	license_edit.text = remembered_license
	fields.add_child(license_edit)
	label(fields, "ORIENTATION / vehicle front faces -Z")
	vector_field("Rotation degrees", rotation_value, func(v): rotation_value = v; invalidate(true))
	label(fields, "Uniform scale")
	number(fields, model_scale, func(v): model_scale = v; invalidate(true), .00001, 1000., .00001)
	button(fields, "Suggest scale for 4.8 m car", suggest_scale)
	label(fields, "Grounding: automatic wheel/foundation level at Y = 0")
	button(fields, "Reinspect / Suggest four wheels", reinspect)
	label(fields, "WHEEL ASSIGNMENT / front is -Z")
	wheel_select = OptionButton.new()
	for index in 4:
		wheel_select.add_item(NAMES[index] + " · " + str(wheel_groups[index].size()) + " pieces")
	wheel_select.select(selected_wheel)
	wheel_select.item_selected.connect(func(index): selected_wheel = index; build_fields(); select_assigned())
	fields.add_child(wheel_select)
	label(fields, "Wheel: " + ", ".join(PackedStringArray(wheel_groups[selected_wheel])) + "\nCaliper: " + ", ".join(PackedStringArray(caliper_groups[selected_wheel])))
	button(fields, "Clear this wheel", func(): wheel_groups[selected_wheel] = []; caliper_groups[selected_wheel] = []; invalidate(); build_fields())
	label(fields, "Guided region selects separated mesh islands near this wheel. Remove any body/spare-wheel pieces from the selection before assigning.")
	vector_field("Triangle correction region centre", region_center, func(v): region_center = v; show_region())
	vector_field("Triangle correction region dimensions", region_size, func(v): region_size = v.abs().max(Vector3.ONE * .001); show_region())
	button(fields, "Split selected island inside region", split_region)
	var wheel: Dictionary = overrides[selected_wheel]
	if converted.get("ok", false) and converted.definition.wheels.size() == 4:
		var current: Dictionary = converted.definition.wheels[selected_wheel]
		if not wheel.has("pivot"): wheel.pivot = LeoVehicleCodec.vector(current.pivot)
		if not wheel.has("radius"): wheel.radius = float(current.radius)
		if not wheel.has("axle"): wheel.axle = LeoVehicleCodec.vector(current.axle)
	vector_field("Pivot (converted model space)", wheel.get("pivot", Vector3.ZERO), func(v): wheel.pivot = v; invalidate())
	vector_field("Rotation axle", wheel.get("axle", Vector3.RIGHT), func(v): wheel.axle = v; invalidate())
	label(fields, "Wheel rolling radius (metres)")
	number(fields, float(wheel.get("radius", .4)), func(v): wheel.radius = v; invalidate(), .02, 3.)
	var steering := toggle(fields, "This wheel steers", bool(wheel.get("steering", selected_wheel < 2)))
	steering.toggled.connect(func(v): wheel.steering = v; invalidate())
	confirm_toggle = toggle(fields, "I confirmed all four rotating wheel groups", confirmed)
	confirm_toggle.toggled.connect(func(v): confirmed = v)
	label(fields, "COLLISION / PREVIEW")
	vector_field("Collision dimensions (metres)", collision_size, func(v): collision_size = v; invalidate())
	vector_field("Collision centre", collision_center, func(v): collision_center = v; invalidate())
	button(fields, "Fit collision to model", fit_collision)
	label(fields, "BLUE BOOST ANCHORS / rear is +Z")
	for anchor in boost_anchors.size():
		vector_field("Boost emitter " + str(anchor + 1), boost_anchors[anchor], func(v): boost_anchors[anchor] = v; invalidate())
	vector_field("Camera target", target, func(v): target = v; position_camera())
	label(fields, "Camera distance")
	number(fields, distance, func(v): distance = v; position_camera(), 1., 250.)
	button(fields, "Choose install destination…", func(): folder_picker.popup_centered_ratio(.75))
	label(fields, "No visible driver is added. Four wheels + steering + blue boost. Imported cars remain modded/unranked.")

func invalidate(reset_confirmation := false) -> void:
	if reset_confirmation:
		confirmed = false
		if is_instance_valid(confirm_toggle): confirm_toggle.button_pressed = false
	converted["dirty"] = true
	status.text = "Changes pending. Apply / Validate to rebuild the preview."

func choose_source() -> void:
	if not busy: file_picker.popup_centered_ratio(.8)

func import_source(path: String) -> void:
	if busy: return
	if path.get_extension().to_lower() != "glb": status.text = "Choose a .glb model."; return
	source = path
	confirmed = false
	rotation_value = Vector3.ZERO
	model_scale = 1.
	overrides = [{}, {}, {}, {}]
	var definition: Dictionary = job.get("source_definition", {})
	if definition.has("normalization"):
		var normalization := LeoVehicleCodec.transform(definition.normalization)
		rotation_value = normalization.basis.get_euler() * 180. / PI
		model_scale = normalization.basis.get_scale().x
	var proposed_id := String(definition.get("id", LeoVehicleSetup.slug(path.get_file().get_basename())))
	if not definition.is_empty(): proposed_id = proposed_id.left(55) + "_custom"
	if is_instance_valid(id_edit): id_edit.text = proposed_id
	if is_instance_valid(name_edit): name_edit.text = String(definition.get("display_name", path.get_file().get_basename()))
	job.erase("source_definition")
	await reinspect()

func reinspect() -> void:
	if busy or source.is_empty(): return
	var alive: WeakRef = weakref(self)
	busy = true
	status.text = "Inspecting geometry and separated islands…"
	source_label.text = source.get_file() + " / source is never overwritten"
	await get_tree().process_frame
	if not is_instance_valid(alive.get_ref()) or not is_inside_tree(): return
	await get_tree().process_frame
	if not is_instance_valid(alive.get_ref()) or not is_inside_tree(): return
	clear_preview()
	if converted.get("scene") is Node and is_instance_valid(converted.scene): converted.scene.free()
	converted = {}
	if inspection.get("scene") is Node and is_instance_valid(inspection.scene): inspection.scene.free()
	worker_result = {}
	worker_task = WorkerThreadPool.add_task(inspect_worker.bind(source, rotation_value, model_scale))
	while not WorkerThreadPool.is_task_completed(worker_task):
		status.text = "Inspecting geometry " + ["·", "··", "···"][int(Time.get_ticks_msec() / 300) % 3] + "  Back remains available."
		await get_tree().process_frame
		if not is_instance_valid(alive.get_ref()) or not is_inside_tree(): return
	WorkerThreadPool.wait_for_task_completion(worker_task)
	worker_task = -1
	inspection = worker_result
	worker_result = {}
	busy = false
	if not inspection.get("ok", false): status.text = String(inspection.get("error", "Cannot inspect GLB")); return
	source_hash = String(inspection.get("source_hash", ""))
	wheel_groups = inspection.get("suggestions", [[], [], [], []]).duplicate(true)
	caliper_groups = inspection.get("calipers", [[], [], [], []]).duplicate(true)
	overrides = [{}, {}, {}, {}]
	confirmed = false
	converted = {}
	model_root = (inspection.scene as Node3D).duplicate()
	studio.add_child(model_root)
	populate_inventory()
	fit_collision()
	boost_anchors = [Vector3(-collision_size.x * .28, collision_size.y * .22, collision_center.z + collision_size.z * .5 + .08), Vector3(collision_size.x * .28, collision_size.y * .22, collision_center.z + collision_size.z * .5 + .08)]
	fit_camera()
	build_fields()
	var dimensions: Vector3 = inspection.bounds.size
	status.text = "Model %.2f × %.2f × %.2f m. Inspect orientation/scale and four wheel groups, then confirm. " % [dimensions.x, dimensions.y, dimensions.z] + "; ".join(PackedStringArray(inspection.get("warnings", [])))

func inspect_worker(path: String, angles: Vector3, scale_value: float) -> void:
	worker_result = Converter.inspect(path, angles, scale_value)

func suggest_scale() -> void:
	if inspection.is_empty(): status.text = "Import a GLB first."; return
	var size: Vector3 = inspection.bounds.size
	model_scale = clampf(model_scale * 4.8 / maxf(maxf(size.x, size.z), .00001), .00001, 1000.)
	invalidate(true)
	build_fields()
	status.text = "Suggested scale %.5f targets a 4.8 m length. Adjust for this vehicle, then Reinspect; this suggestion is not applied automatically." % model_scale

func populate_inventory() -> void:
	inventory.clear()
	var query := inventory_filter.text.strip_edges().to_lower() if is_instance_valid(inventory_filter) else ""
	for island: Dictionary in inspection.get("islands", []):
		var text := String(island.id) + " · " + String(island.get("name", island.id)) + " · " + String(island.get("kind", "mesh")) + " · " + str(island.get("triangles", 0)) + " triangles"
		if not query.is_empty() and query not in text.to_lower(): continue
		var index := inventory.add_item(text)
		inventory.set_item_metadata(index, String(island.id))
		inventory.set_item_tooltip(index, text + "\nCentre (metres): " + str(island.center) + "\nSize (metres): " + str(island.bounds.size))

func select_assigned() -> void:
	inventory.deselect_all()
	for index in inventory.item_count:
		if String(inventory.get_item_metadata(index)) in wheel_groups[selected_wheel]: inventory.select(index, false)
	highlight_selection()

func assign_selection(caliper: bool) -> void:
	var ids: Array = []
	for index in inventory.get_selected_items(): ids.append(String(inventory.get_item_metadata(index)))
	if ids.is_empty(): status.text = "Select at least one mesh island first."; return
	if caliper: caliper_groups[selected_wheel] = ids
	else: wheel_groups[selected_wheel] = ids
	confirmed = false
	overrides[selected_wheel] = {}
	invalidate()
	build_fields()

func select_region() -> void:
	if inspection.is_empty(): return
	var box: AABB = inspection.bounds
	var pivot := box.get_center() + Vector3((-1. if selected_wheel % 2 == 0 else 1.) * box.size.x * .4, -box.size.y * .25, (-1. if selected_wheel < 2 else 1.) * box.size.z * .3)
	region_center = pivot
	region_size = Vector3(box.size.x * .6, box.size.y * .55, box.size.z * .48)
	inventory.deselect_all()
	var count := 0
	for index in inventory.item_count:
		var id := String(inventory.get_item_metadata(index))
		for island: Dictionary in inspection.get("islands", []):
			if String(island.id) != id: continue
			var center: Vector3 = island.get("center", (island.bounds as AABB).get_center())
			if absf(center.x - pivot.x) < box.size.x * .3 and absf(center.z - pivot.z) < box.size.z * .24 and center.y < box.position.y + box.size.y * .55:
				inventory.select(index, false)
				count += 1
	highlight_selection()
	status.text = "Guided region selected %d pieces. Check the highlight, remove body pieces, then Use as wheel." % count
	build_fields()

func show_region() -> void:
	if is_instance_valid(selection_hint): selection_hint.free()
	selection_hint = hint(AABB(region_center - region_size * .5, region_size), Color(1., .5, .05, .22))

func split_region() -> void:
	if inventory.get_selected_items().size() != 1:
		status.text = "Select exactly one island, then position the orange region around the wheel triangles to separate."
		return
	var id := String(inventory.get_item_metadata(inventory.get_selected_items()[0]))
	var triangles := PackedInt32Array()
	var region := AABB(region_center - region_size * .5, region_size)
	for island: Dictionary in inspection.get("islands", []):
		if String(island.id) != id: continue
		var vertices: PackedVector3Array = island.arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = island.indices
		for triangle in int(island.triangles):
			var offset := triangle * 3
			var center := (vertices[indices[offset]] + vertices[indices[offset + 1]] + vertices[indices[offset + 2]]) / 3.
			if region.has_point(center): triangles.append(triangle)
	var result: Dictionary = Converter.split_island(inspection, id, triangles)
	if not result.get("ok", false): status.text = String(result.get("error", "Cannot split this region.")); return
	confirmed = false
	invalidate()
	populate_inventory()
	for index in inventory.item_count:
		if inventory.get_item_metadata(index) == result.id: inventory.select(index)
	show_region()
	build_fields()
	status.text = "Separated %d triangles. The new piece is selected; Use as wheel or caliper after checking it. Reinspect resets corrections." % triangles.size()

func material(color: Color) -> StandardMaterial3D:
	var value := StandardMaterial3D.new()
	value.albedo_color = color
	return value

func hint(box: AABB, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size.max(Vector3.ONE * .02)
	node.mesh = mesh
	node.position = box.get_center()
	var mat := material(color)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = mat
	studio.add_child(node)
	return node

func highlight_selection() -> void:
	if is_instance_valid(selection_hint): selection_hint.free()
	var bounds := AABB()
	var found := false
	for index in inventory.get_selected_items():
		for island: Dictionary in inspection.get("islands", []):
			if String(island.id) != String(inventory.get_item_metadata(index)): continue
			var box: AABB = island.bounds
			bounds = bounds.merge(box) if found else box
			found = true
	if found: selection_hint = hint(bounds, Color(1., .65, .05, .3))

func fit_collision() -> void:
	if inspection.is_empty(): return
	var box: AABB = inspection.bounds
	collision_size = box.size.max(Vector3.ONE * .1)
	collision_center = box.get_center()
	build_fields()

func fit_camera() -> void:
	if not inspection.is_empty():
		var box: AABB = inspection.bounds
		target = box.get_center()
		distance = maxf(3., box.size.length() * 1.3)
		front_marker.position = Vector3(box.get_center().x, .1, box.position.z - .75)
	position_camera()

func position_camera() -> void:
	camera.position = target + Vector3(sin(yaw) * distance, distance * .35, cos(yaw) * distance)
	if camera.position.distance_to(target) > .01: camera.look_at(target)

func preview_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		yaw -= event.relative.x * .01
		position_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			distance = clampf(distance * (.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), .5, 250.)
			position_camera()

func options() -> Dictionary:
	return {"inspection": inspection, "rotation_degrees": rotation_value, "scale": model_scale, "grounded": grounded, "id": id_edit.text.strip_edges(), "display_name": name_edit.text.strip_edges(), "wheel_groups": wheel_groups.duplicate(true), "caliper_groups": caliper_groups.duplicate(true)}

func build_preview() -> bool:
	if busy: return false
	if inspection.is_empty(): status.text = "Import a GLB first."; return false
	if not rotation_value.is_equal_approx(inspection.get("rotation_degrees", Vector3.ZERO)) or not is_equal_approx(model_scale, float(inspection.get("scale", 1.))):
		status.text = "Orientation or scale changed. Reinspect / Suggest four wheels, then reconfirm the assignments."
		return false
	if not confirmed: status.text = "Inspect and confirm all four wheel assignments before converting."; return false
	for group: Array in wheel_groups:
		if group.is_empty(): status.text = "Each of the four wheels needs at least one rotating piece."; return false
	busy = true
	var alive: WeakRef = weakref(self)
	status.text = "Building game-ready preview…"
	await get_tree().process_frame
	if not is_instance_valid(alive.get_ref()) or not is_inside_tree(): return false
	clear_preview()
	if converted.get("scene") is Node and is_instance_valid(converted.scene): converted.scene.free()
	converted = Converter.convert(source, options())
	busy = false
	if not converted.get("ok", false): status.text = String(converted.get("error", "Conversion failed")); return false
	var definition: Dictionary = converted.definition
	definition.driver_policy = 1
	definition.setup_complete = true
	definition.attribution = license_edit.text
	definition.collision_size = LeoVehicleCodec.encode(collision_size)
	definition.collision_position = LeoVehicleCodec.encode(collision_center)
	definition.preview_target = LeoVehicleCodec.encode(target)
	definition.preview_distance = distance
	for index in 4:
		var wheel: Dictionary = definition.wheels[index]
		for key in overrides[index]:
			wheel[key] = LeoVehicleCodec.encode(overrides[index][key])
		wheel.steering = bool(overrides[index].get("steering", index < 2))
	var problems := LeoVehicleLibrary.problems(definition, "", false)
	if not problems.is_empty():
		status.text = "; ".join(problems)
		return false
	# Converted GLB is canonical; exhausts belong in game/metre coordinates.
	definition.exhausts = boost_anchors.map(func(point): return LeoVehicleCodec.encode(point))
	wheel_preview = LeoKart.new()
	wheel_preview.set_process(false)
	wheel_preview.set_physics_process(false)
	studio.add_child(wheel_preview)
	model_root = (converted.scene as Node3D).duplicate()
	model_root.name = "Chassis"
	wheel_preview.add_child(model_root)
	wheel_preview.chassis = model_root
	wheel_preview.visual = model_root
	wheel_preview.definition = LeoVehicleCodec.deserialize(definition, source.get_base_dir())
	wheel_preview.wheel_radius = wheel_preview.definition.wheels[0].radius
	for binding in wheel_preview.definition.wheels: wheel_preview.attach_binding(binding)
	for point in definition.exhausts:
		var flame := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = .12
		cone.bottom_radius = .025
		cone.height = .9
		flame.mesh = cone
		flame.position = LeoVehicleCodec.vector(point) + Vector3(0, 0, .3)
		flame.rotation_degrees.x = 90
		var blue := material(Color("18bfff"))
		blue.emission_enabled = true
		blue.emission = Color("14aaff")
		blue.emission_energy_multiplier = 2.
		flame.material_override = blue
		studio.add_child(flame)
		flames.append(flame)
	collision_hint = hint(AABB(collision_center - collision_size * .5, collision_size), Color(.05, 1., 1., .12))
	collision_hint.visible = collision_toggle.button_pressed
	converted.dirty = false
	build_fields()
	status.text = "Authored lights/actions and original model retained. After installing, use Content > Vehicles > Set Up Vehicle to adjust their poses and bindings." if converted.get("source_model","")!="" else "Preview ready: verify four wheels, front steering, collision and blue boost. Install creates a portable Vehicle API 1 folder."
	return true

func clear_preview() -> void:
	if is_instance_valid(wheel_preview): wheel_preview.free()
	elif is_instance_valid(model_root): model_root.free()
	wheel_preview = null
	model_root = null
	if is_instance_valid(collision_hint): collision_hint.free()
	if is_instance_valid(selection_hint): selection_hint.free()
	for flame in flames:
		if is_instance_valid(flame): flame.free()
	flames.clear()

func export_to(root: String) -> Dictionary:
	var alive: WeakRef = weakref(self)
	if converted.get("dirty", true) or not converted.get("ok", false):
		var valid: bool = await build_preview()
		if not is_instance_valid(alive.get_ref()) or not is_inside_tree(): return {"ok": false, "error": "Cancelled"}
		if not valid: return {"ok": false, "error": status.text}
	var id := id_edit.text.strip_edges()
	if id.is_empty() or not LeoVehicleLibrary.safe_relative(id) or "/" in id or "\\" in id:
		return {"ok": false, "error": "Choose a safe unique vehicle ID."}
	converted.definition.id = id
	converted.definition.display_name = name_edit.text.strip_edges()
	converted.definition.attribution = license_edit.text
	converted.definition.preview_target = LeoVehicleCodec.encode(target)
	converted.definition.preview_distance = distance
	var destination := root.path_join(id)
	if DirAccess.dir_exists_absolute(destination):
		return {"ok": false, "error": "That folder already exists. Choose another ID; existing vehicles are never overwritten."}
	if DisplayServer.get_name() != "headless":
		var helpers: Array = [front_marker, collision_hint, selection_hint] + flames
		var visibility: Array[bool] = []
		for helper in helpers:
			visibility.append(is_instance_valid(helper) and helper.visible)
			if is_instance_valid(helper): helper.hide()
		await get_tree().process_frame
		if not is_instance_valid(alive.get_ref()) or not is_inside_tree(): return {"ok": false, "error": "Cancelled before export"}
		await RenderingServer.frame_post_draw
		if not is_instance_valid(alive.get_ref()) or not is_inside_tree(): return {"ok": false, "error": "Cancelled before export"}
		converted.thumbnail = await LeoPreviewArt.capture_model(studio,viewport,get_tree())
		for index in helpers.size():
			if is_instance_valid(helpers[index]): helpers[index].visible = visibility[index]
	# The real thumbnail is staged together with GLB/metadata, not changed after
	# the complete folder becomes discoverable by the running game.
	return Converter.export_folder(converted, destination)

func install_vehicle() -> void:
	if busy or exporting: return
	exporting = true
	var alive: WeakRef = weakref(self)
	var result: Dictionary = await export_to(save_root)
	if not is_instance_valid(alive.get_ref()) or not is_inside_tree(): return
	exporting = false
	if not result.get("ok", false): status.text = String(result.get("error", "Cannot install. Choose a writable destination.")); return
	status.text = "Installed " + String(result.get("folder", "")) + ". Back returns to the game; Refresh Content discovers this car."
	completed.emit({"status": "saved", "folder": result.get("folder", save_root.path_join(id_edit.text)), "id": id_edit.text, "error": ""})

func private_test() -> void:
	if busy or exporting: return
	exporting = true
	var alive: WeakRef = weakref(self)
	var root := "user://vehicle-workshop-tests/" + str(Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(root)
	var result: Dictionary = await export_to(root)
	if not is_instance_valid(alive.get_ref()) or not is_inside_tree(): return
	exporting = false
	if not result.get("ok", false): status.text = String(result.get("error", "Cannot prepare private test.")); return
	var folder := ProjectSettings.globalize_path(String(result.get("folder", root.path_join(id_edit.text))))
	var arguments := PackedStringArray(["--", "--workshop-test=" + folder])
	if OS.has_feature("editor"):
		arguments = PackedStringArray(["--path", ProjectSettings.globalize_path("res://"), "--", "--workshop-test=" + folder])
	var pid := OS.create_process(OS.get_executable_path(), arguments)
	status.text = "Private test opened in another window. Close that window to return; no official records are written." if pid > 0 else "Could not launch the private test. Your editable preview is retained."

func cancel() -> void:
	completed.emit({"status": "cancelled", "folder": "", "id": "", "error": ""})
	if get_signal_connection_list("completed").is_empty(): get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if file_picker.visible: file_picker.hide()
		elif folder_picker.visible: folder_picker.hide()
		else: cancel()
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	elapsed += dt
	if is_instance_valid(wheel_preview):
		wheel_preview.wheel_motion_speed = 8. if spin_toggle.button_pressed else 0.
		wheel_preview.steer = sin(elapsed * 1.4) * .65 if steer_toggle.button_pressed else 0.
		wheel_preview.animate_wheels(dt)
	for flame in flames:
		flame.visible = boost_toggle.button_pressed
		flame.scale = Vector3.ONE * (.85 + sin(elapsed * 35.) * .15)

func _exit_tree() -> void:
	generation += 1
	if worker_task >= 0:
		WorkerThreadPool.wait_for_task_completion(worker_task)
		if worker_result.get("scene") is Node and is_instance_valid(worker_result.scene): worker_result.scene.free()
	if inspection.get("scene") is Node and is_instance_valid(inspection.scene): inspection.scene.free()
	if converted.get("scene") is Node and is_instance_valid(converted.scene): converted.scene.free()

