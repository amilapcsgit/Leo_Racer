class_name LeoControlsPanel
extends PanelContainer
signal closed
var router: LeoInputRouter
var slot := 0
var body: VBoxContainer
var status: Label
var live: Dictionary = {}
func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left",40);margin.add_theme_constant_override("margin_right",40);margin.add_theme_constant_override("margin_top",24);margin.add_theme_constant_override("margin_bottom",24);add_child(margin)
 body = VBoxContainer.new();body.add_theme_constant_override("separation",9);margin.add_child(body)
 router.binding_changed.connect(refresh)
 refresh()
func label(text: String, parent: Node = null) -> Label:
 if parent == null: parent = body
 var node := Label.new();node.text=text;node.add_theme_font_size_override("font_size",19);parent.add_child(node);return node
func button(text: String, callback: Callable, parent: Node = null) -> Button:
 if parent == null: parent = body
 var node := Button.new();node.text=text;node.custom_minimum_size.y=36;node.pressed.connect(callback);parent.add_child(node);return node
func refresh() -> void:
 for child in body.get_children(): body.remove_child(child);child.queue_free()
 live.clear()
 label("CONTROLS / PLAYER %d" % (slot+1)).add_theme_font_size_override("font_size",30)
 var tabs := HBoxContainer.new();body.add_child(tabs)
 for i in 2:
  var target := i
  button("PLAYER %d" % (i+1),func():slot=target;refresh(),tabs)
 button("BACK",func():router.cancel_capture();closed.emit(),tabs)
 var devices := OptionButton.new();body.add_child(devices)
 devices.add_item("Keyboard");devices.set_item_metadata(0,{"kind":"keyboard","device":-1})
 for id in Input.get_connected_joypads():
  for mode in ["gamepad","wheel"]:
   devices.add_item("%s / %s #%d" % [Input.get_joy_name(id),mode.to_upper(),id]);devices.set_item_metadata(devices.item_count-1,{"kind":mode,"device":id})
 var p := router.players[slot]
 var selected := -1
 for i in devices.item_count:
  var data: Dictionary = devices.get_item_metadata(i)
  if data.kind==p.kind and int(data.device)==p.device:selected=i
 if selected < 0:
  devices.add_item("DISCONNECTED / choose device");devices.set_item_disabled(devices.item_count-1,true);selected=devices.item_count-1
 devices.select(selected)
 devices.item_selected.connect(func(index: int):
  var data: Dictionary=devices.get_item_metadata(index)
  if not router.assign(slot,data.kind,data.device):status.text=router.last_error)
 status=label(router.last_error if not router.last_error.is_empty() else "Release controls before rebinding. Press Escape to cancel. One keyboard player maximum.")
 status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(scroll)
 var rows:=VBoxContainer.new();rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(rows)
 for action in LeoPlayerInput.ACTIONS:
  var target: String=action
  var row:=HBoxContainer.new();rows.add_child(row)
  var title:=label(action.replace("_"," ").to_upper(),row);title.custom_minimum_size.x=180
  var bind:=button(p.describe(action),func():router.start_capture(slot,target);status.text="Player %d: press a key/button or move fully toward %s. Escape cancels." % [slot+1,target],row);bind.custom_minimum_size.x=360
  var value_label:=label("0.00",row);live[action]=value_label
  var entries: Array=p.bindings.get(action,[])
  if not entries.is_empty() and entries[0].get("type")=="axis":
   var entry: Dictionary=entries[0]
   for field in ["rest","pressed","deadzone","sensitivity"]:
    var key: String=field
    var spin:=SpinBox.new();spin.min_value=.25 if field=="sensitivity" else (0. if field=="deadzone" else -1.);spin.max_value=3. if field=="sensitivity" else (.5 if field=="deadzone" else 1.);spin.step=.01;spin.value=float(entry.get(field,1. if field in ["pressed","sensitivity"] else .03 if field=="deadzone" else 0.));spin.custom_minimum_size.x=105;spin.tooltip_text=field;row.add_child(spin)
    spin.value_changed.connect(func(value: float):
     if key in ["rest","pressed"] and absf(value-float(entry.get("pressed" if key=="rest" else "rest",0.)))<.1:status.text="Rest and full travel must differ by at least 0.1.";return
     entry[key]=value;router.save_profiles())
 button("RESET THIS PLAYER TO DEFAULTS",func():p.reset_defaults(p.kind);router.save_profiles();refresh())
 label("Axis fields: rest / full travel / deadzone / sensitivity. Bind left and right from centered steering.")
 label("Combined pedals: bind accelerate and brake from neutral to each opposite end. Wheel force feedback is not included.")
func _process(_dt: float) -> void:
 if not router:return
 var p:=router.players[slot]
 for action in live:
  if is_instance_valid(live[action]):live[action].text="%.2f" % p.value(action)
func _exit_tree() -> void:
 if router and router.binding_changed.is_connected(refresh):router.binding_changed.disconnect(refresh)
