extends SceneTree
const Workshop = preload("res://tools/vehicle_workshop/workshop.gd")
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		quit(1)
	else:
		checks += 1

func run() -> void:
	var directory := "res://build/customcars-ui-tests/" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	var fixture := Node3D.new()
	fixture.name = "Car"
	var body := MeshInstance3D.new()
	body.name = "Body"
	var box := BoxMesh.new()
	box.size = Vector3(1.8, 1.2, 3.8)
	body.mesh = box
	body.position.y = 1.1
	fixture.add_child(body)
	body.owner = fixture
	for index in 4:
		var wheel := MeshInstance3D.new()
		wheel.name = "wheel_%d" % index
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = .4
		cylinder.bottom_radius = .4
		cylinder.height = .25
		wheel.mesh = cylinder
		wheel.rotation.z = PI / 2.
		wheel.position = Vector3(-1. if index % 2 == 0 else 1., .4, -1.3 if index < 2 else 1.3)
		fixture.add_child(wheel)
		wheel.owner = fixture
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var source := directory.path_join("fixture.glb")
	check(document.append_from_scene(fixture, state) == OK and document.write_to_filesystem(state, source) == OK, "fixture export")
	fixture.free()
	var original := FileAccess.get_sha256(source)
	var ui := Workshop.new()
	ui.configure({"vehicles_root": directory.path_join("vehicles")})
	root.add_child(ui)
	await process_frame
	check(is_instance_valid(ui.file_picker) and ui.file_picker.use_native_dialog, "native file picker")
	check(not await ui.build_preview(), "confirmation blocks empty conversion")
	await ui.import_source(source)
	check(ui.inspection.get("ok", false), "threaded inspection")
	check(ui.inventory.item_count >= 5, "island inventory populated")
	var total_pieces: int = ui.inventory.item_count
	ui.inventory_filter.text = "wheel"
	ui.populate_inventory()
	check(ui.inventory.item_count > 0 and ui.inventory.item_count < total_pieces, "large island inventories can be filtered")
	ui.inventory_filter.text = ""
	ui.populate_inventory()
	check(ui.wheel_groups.all(func(group): return not group.is_empty()), "all four wheels suggested")
	check(not await ui.build_preview(), "suggestions require explicit confirmation")
	ui.confirmed = true
	check(await ui.build_preview(), "canonical animated preview")
	check(ui.wheel_preview.wheel_spin_pivots.size() == 4, "four rotating wheel pivots")
	ui.boost_toggle.button_pressed = true
	ui._process(.016)
	check(ui.flames.size() == 2 and ui.flames[0].visible, "blue boost visible")
	ui.selected_wheel = 0
	ui.select_region()
	check(not ui.inventory.get_selected_items().is_empty(), "guided region selection")
	var result: Dictionary = await ui.export_to(directory.path_join("vehicles"))
	check(result.get("ok", false), "portable staged folder export: " + str(result))
	check(FileAccess.get_sha256(source) == original, "source remains unchanged")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(result.get("folder", "")).path_join("vehicle.json")))
	check(data.get("driver_policy", -1) == 1 and data.wheels.size() == 4 and data.exhausts.size() == 2, "no driver, four wheels, boost bindings")
	check(not (await ui.export_to(directory.path_join("vehicles"))).get("ok", false), "existing folder protected")
	var previous_islands: int = ui.inventory.item_count
	ui.inventory.deselect_all()
	for index in ui.inventory.item_count:
		for island: Dictionary in ui.inspection.islands:
			if ui.inventory.get_item_metadata(index) == island.id and island.name == "Body": ui.inventory.select(index)
	ui.region_center = Vector3(.9, 1.1, 0)
	ui.region_size = Vector3(.1, 3., 5.)
	ui.split_region()
	check(ui.inventory.item_count == previous_islands + 1, "guided triangle-region correction")
	var previous_conversion: WeakRef=weakref(ui.converted.scene)
	await ui.reinspect()
	check(previous_conversion.get_ref()==null, "reinspection frees the old detached conversion")
	var response: Dictionary = {}
	ui.completed.connect(func(value): response.merge(value, true))
	ui.cancel()
	check(response.get("status") == "cancelled", "Back/Escape return signal")
	ui.queue_free()
	await process_frame
	var cancelled_ui := Workshop.new()
	root.add_child(cancelled_ui)
	await process_frame
	cancelled_ui.import_source(source)
	cancelled_ui.queue_free()
	await process_frame
	await process_frame
	check(not is_instance_valid(cancelled_ui), "close while import pending is safe")
	print("CUSTOMCARS_WORKSHOP_UI PASS checks=", checks)
	quit()
