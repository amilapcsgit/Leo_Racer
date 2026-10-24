class_name LeoContentManager
extends CanvasLayer
var game: Node
var panel: PanelContainer
var list: VBoxContainer
var status: Label

func _ready() -> void:
	layer=90;process_mode=Node.PROCESS_MODE_ALWAYS
	panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.theme=load("res://assets/ui/theme.tres");add_child(panel)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,32)
	panel.add_child(margin);var box:=VBoxContainer.new();margin.add_child(box)
	var title:=Label.new();title.text="CONTENT / VEHICLES";title.add_theme_font_size_override("font_size",38);box.add_child(title)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(status)
	var buttons:=HBoxContainer.new();box.add_child(buttons)
	button(buttons,"Refresh Content",refresh).grab_focus()
	button(buttons,"Open Vehicles Folder",func():OS.shell_open(LeoVehicleLibrary.default_root()))
	button(buttons,"Back",func():
		if game.hud:queue_free()
		else:get_tree().quit())
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(scroll)
	list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	populate()

func button(parent: Node, text: String, action: Callable) -> Button:
	var node:=Button.new();node.text=text;node.custom_minimum_size=Vector2(200,52);node.pressed.connect(action);parent.add_child(node);return node

func populate() -> void:
	for child in list.get_children():child.queue_free()
	status.text="%d compatible vehicles · %d need setup · %d unavailable\nAdd a vehicle folder or a GLB, then refresh. Content refresh is available outside races."%[LeoVehicleLibrary.entries.size(),LeoVehicleLibrary.pending.size(),LeoVehicleLibrary.unavailable.size()]
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
	if game.state not in ["menu","lobby"]:status.text="Return home before refreshing content.";return
	game.refresh_content();populate()

func edit_vehicle(vehicle: VehicleDefinition) -> void:
	var editor: CanvasLayer=load("res://scripts/content/vehicle_setup.gd").new();editor.game=game;editor.configure(vehicle);game.add_child(editor);hide();editor.tree_exited.connect(func():show();populate())

func setup_glb(path: String) -> void:
	var editor: CanvasLayer=load("res://scripts/content/vehicle_setup.gd").new();editor.game=game;editor.configure(null,path);game.add_child(editor);hide();editor.tree_exited.connect(func():show();populate())
