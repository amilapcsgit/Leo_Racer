class_name LeoContentManager
extends CanvasLayer
var game: Node
var panel: PanelContainer
var list: VBoxContainer
var status: Label
var refresh_button: Button
var refreshing := false
var refreshed_at := ""

func _ready() -> void:
	layer=90;process_mode=Node.PROCESS_MODE_ALWAYS
	var shade:=ColorRect.new();shade.color=Color("091522");shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.theme=load("res://assets/ui/theme.tres");add_child(panel)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,32)
	panel.add_child(margin);var box:=VBoxContainer.new();margin.add_child(box)
	var title:=Label.new();title.text="CONTENT / VEHICLES";title.add_theme_font_size_override("font_size",38);box.add_child(title)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(status)
	var buttons:=HBoxContainer.new();box.add_child(buttons)
	refresh_button=button(buttons,"Refresh Content",refresh);refresh_button.grab_focus()
	button(buttons,"Open Vehicles Folder",func():OS.shell_open(LeoVehicleLibrary.default_root()))
	button(buttons,"Back",func():
		if refreshing:return
		if game.catalog.vehicles.is_empty():status.text="Add a compatible vehicle before returning to the menu.";return
		if game.hud:
			if game.state=="lobby":game.hud.frontend.show_setup()
			else:game.hud.frontend.show_home()
			queue_free()
		else:get_tree().quit())
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(scroll)
	list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	populate()

func button(parent: Node, text: String, action: Callable) -> Button:
	var node:=Button.new();node.text=text;node.custom_minimum_size=Vector2(200,52);node.pressed.connect(action);parent.add_child(node);return node

func populate() -> void:
	for child in list.get_children():list.remove_child(child);child.queue_free()
	status.text="%d compatible vehicles · %d need setup · %d unavailable\nAdd a vehicle folder or a GLB, then refresh. Content refresh is available outside races."%[LeoVehicleLibrary.entries.size(),LeoVehicleLibrary.pending.size(),LeoVehicleLibrary.unavailable.size()]
	status.text+="\nVehicles folder: "+LeoVehicleLibrary.default_root()+("\nRefreshed "+refreshed_at if not refreshed_at.is_empty() else "")
	for entry in LeoVehicleLibrary.entries:
		var row:=HBoxContainer.new();list.add_child(row)
		var text:=Label.new();text.text=entry.display_name+(" / official" if entry.official else " / modded");text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(text)
		button(row,"Set Up Vehicle",func():edit_vehicle(entry))
	for path in LeoVehicleLibrary.pending:
		var row:=HBoxContainer.new();list.add_child(row);var text:=Label.new();text.text=path.get_file()+" / Needs Setup";text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(text)
		button(row,"Set Up Vehicle",func():setup_glb(path))
	for item in LeoVehicleLibrary.unavailable:
		var text:=Label.new();text.text=item.folder+" / "+item.reason;text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;list.add_child(text)

func refresh() -> void:
	if refreshing:return
	if game.state not in ["menu","lobby"]:status.text="Return home before refreshing content.";return
	refreshing=true;refresh_button.disabled=true;status.text="Scanning installed vehicle folders…"
	await get_tree().process_frame
	var updated: bool=await game.refresh_content()
	if not is_inside_tree():return
	refreshing=false;refresh_button.disabled=false
	if updated:
		refreshed_at=Time.get_time_string_from_system();populate()
	else:status.text="Content could not be refreshed while a race or another refresh is active."
	refresh_button.grab_focus()

func edit_vehicle(vehicle: VehicleDefinition) -> void:
	var editor: CanvasLayer=load("res://scripts/content/vehicle_setup.gd").new();editor.game=game;editor.configure(vehicle);game.add_child(editor);hide();editor.tree_exited.connect(resume_list)

func setup_glb(path: String) -> void:
	var editor: CanvasLayer=load("res://scripts/content/vehicle_setup.gd").new();editor.game=game;editor.configure(null,path);game.add_child(editor);hide();editor.tree_exited.connect(resume_list)

func resume_list() -> void:
	if not is_inside_tree():return
	show();await refresh()
