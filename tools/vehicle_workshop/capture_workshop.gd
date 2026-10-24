extends SceneTree
const Workshop = preload("res://tools/vehicle_workshop/workshop.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var width := 1280
	var source := OS.get_environment("LEO_WORKSHOP_CAPTURE_GLB")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-width="): width = int(argument.trim_prefix("--capture-width="))
		if argument.begins_with("--capture-source="): source = argument.trim_prefix("--capture-source=")
	if source.is_empty():
		push_error("Pass --capture-source=<local GLB> or LEO_WORKSHOP_CAPTURE_GLB.")
		quit(1)
		return
	root.size = Vector2i(width, width * 9 / 16)
	DisplayServer.window_set_size(root.size)
	var ui := Workshop.new()
	root.add_child(ui)
	await process_frame
	ui.source = source
	ui.model_scale = 100.
	ui.rotation_value = Vector3(0, 180, 0)
	await ui.reinspect()
	ui.name_edit.text = "2023 BYD Yangwang U8"
	ui.id_edit.text = "byd_yangwang_u8_preview"
	ui.confirmed = true
	var converted: bool = await ui.build_preview()
	if not converted:
		push_error(ui.status.text)
		quit(1)
		return
	ui.steer_toggle.button_pressed = true
	ui.boost_toggle.button_pressed = true
	ui.selected_wheel = 0
	ui.select_assigned()
	for index in 6: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/customcars-ui-captures")
	var path := "res://build/customcars-ui-captures/workshop-%d.png" % width
	root.get_texture().get_image().save_png(path)
	var scroll := ui.fields.get_parent() as ScrollContainer
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	for index in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/customcars-ui-captures/workshop-%d-controls.png" % width)
	print("WORKSHOP_VISUAL_CAPTURE ", path, " dimensions=", root.size, " islands=", ui.inventory.item_count, " vehicle_dimensions=", ui.inspection.bounds.size, " four_wheels=", ui.wheel_preview.wheel_spin_pivots.size())
	ui.queue_free()
	await process_frame
	quit()
