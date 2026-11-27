class_name LeoContentManager
extends CanvasLayer
var game: Node
var panel: PanelContainer
var list: VBoxContainer
var status: Label
var refresh_button: Button
var refreshing := false
var refreshed_at := ""
var browser: FileDialog
var browser_open := false
var browser_dismissed_until := 0
var returning := false

func _ready() -> void:
	layer=90;process_mode=Node.PROCESS_MODE_ALWAYS
	var shade:=ColorRect.new();shade.color=Color("091522");shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.theme=load("res://assets/ui/theme.tres");add_child(panel)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,32)
	panel.add_child(margin);var box:=VBoxContainer.new();margin.add_child(box)
	var title:=Label.new();title.text="CONTENT / VEHICLES";title.add_theme_font_size_override("font_size",44);box.add_child(title)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(status)
	var buttons:=HFlowContainer.new();box.add_child(buttons)
	refresh_button=button(buttons,"Refresh Content",refresh);refresh_button.grab_focus()
	button(buttons,"Import GLB…",browse_glb)
	button(buttons,"Vehicle Workshop",func():launch_workshop(""))
	button(buttons,"Open Vehicles Folder",func():OS.shell_open(LeoVehicleLibrary.default_root()))
	button(buttons,"Back" if game.hud else "Quit to Desktop",close)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(scroll)
	list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	populate()
	browser=FileDialog.new();browser.theme=panel.theme;browser.title="Import vehicle GLB";browser.access=FileDialog.ACCESS_FILESYSTEM;browser.file_mode=FileDialog.FILE_MODE_OPEN_FILE;browser.filters=PackedStringArray(["*.glb ; glTF binary model"]);browser.use_native_dialog=true;add_child(browser)
	browser.file_selected.connect(func(path: String):dismiss_browser();setup_glb(path))
	browser.canceled.connect(dismiss_browser)

func browse_glb() -> void:
	if refreshing:return
	browser_open=true
	browser.popup_centered_ratio(.8)

func dismiss_browser() -> void:
	browser_open=false
	# Native dialogs do not reliably set Window.visible, and Windows may deliver
	# the closing Escape to the owner after its cancellation callback.
	browser_dismissed_until=Time.get_ticks_msec()+250
	refresh_button.grab_focus()

func close() -> void:
	if returning:return
	returning=true
	if game.hud:
		if game.state=="lobby" and not game.catalog.vehicles.is_empty():game.hud.frontend.show_setup()
		else:game.hud.frontend.show_home()
		queue_free()
	else:game.quit_game()

func _input(event: InputEvent) -> void:
	if not visible or returning or browser_open or Time.get_ticks_msec()<browser_dismissed_until or (browser and browser.visible):return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE):
		get_viewport().set_input_as_handled();close()

func button(parent: Node, text: String, action: Callable) -> Button:
	var node:=Button.new();node.text=text;node.custom_minimum_size=Vector2(200,52);node.pressed.connect(action);parent.add_child(node);return node

func populate() -> void:
	for child in list.get_children():list.remove_child(child);child.queue_free()
	status.text="%d compatible vehicles · %d need setup · %d unavailable\nAdd a vehicle folder or a GLB, then refresh. Content refresh is available outside races."%[LeoVehicleLibrary.entries.size(),LeoVehicleLibrary.pending.size(),LeoVehicleLibrary.unavailable.size()]
	status.text+="\nVehicles folder: "+LeoVehicleLibrary.default_root()+("\nRefreshed "+refreshed_at if not refreshed_at.is_empty() else "")
	for entry in LeoVehicleLibrary.entries:
		var row:=HBoxContainer.new();list.add_child(row)
		var text:=Label.new();text.text=entry.display_name+(" / official" if entry.official else " / modded");text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;text.custom_minimum_size=Vector2(240,48);text.clip_text=true;text.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;row.add_child(text)
		button(row,"Set Up Vehicle",func():edit_vehicle(entry))
	for path in LeoVehicleLibrary.pending:
		var row:=HBoxContainer.new();list.add_child(row);var text:=Label.new();text.text=path.get_file()+" / Needs Setup";text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;text.custom_minimum_size=Vector2(240,48);text.clip_text=true;text.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;row.add_child(text)
		button(row,"Set Up Vehicle",func():setup_glb(path))
	for item in LeoVehicleLibrary.unavailable:
		var text:=Label.new();text.text=item.folder+" / "+item.reason;text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;list.add_child(text)

func refresh() -> void:
	if refreshing:return
	if game.state not in ["menu","lobby"]:status.text="Return home before refreshing content.";return
	refreshing=true;refresh_button.disabled=true;status.text="Scanning installed vehicle folders…"
	await get_tree().process_frame
	var updated: bool=await game.refresh_content()
	if not is_inside_tree() or returning:return
	refreshing=false;refresh_button.disabled=false
	if updated:
		refreshed_at=Time.get_time_string_from_system();populate()
	else:status.text="Content could not be refreshed while a race or another refresh is active."
	refresh_button.grab_focus()

func edit_vehicle(vehicle: VehicleDefinition) -> void:
	var editor: CanvasLayer=load("res://scripts/content/vehicle_setup.gd").new();editor.game=game;editor.configure(vehicle);game.add_child(editor);hide();editor.tree_exited.connect(resume_list)

func setup_glb(path: String) -> void:
	launch_workshop(path)

func launch_workshop(path: String) -> void:
	if refreshing or game.state not in ["menu","lobby"]:return
	var helper:=LeoWorkshopLauncher.launch(game,path)
	if not helper:status.text="Vehicle Workshop could not start. Check the Tools/VehicleWorkshop folder in this installation.";return
	status.text="Vehicle Workshop opened in a separate window. Import, test and install locally; close it to refresh this list."
	if not helper.completed.is_connected(workshop_closed):helper.completed.connect(workshop_closed)

func workshop_closed(result: Dictionary) -> void:
	if not is_inside_tree() or returning:return
	await refresh()
	if not is_inside_tree():return
	if result.get("status")=="saved":status.text+="\nInstalled "+String(result.get("id","vehicle"))+". Select it in the garage."
	elif not String(result.get("error","")).is_empty():status.text+="\n"+String(result.error)

func resume_list() -> void:
	if not is_inside_tree():return
	show();await refresh()
