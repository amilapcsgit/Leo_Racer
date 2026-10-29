class_name LeoControlsPanel
extends PanelContainer
signal closed
var router: LeoInputRouter
var slot := 0
var body: VBoxContainer
var status: Label
var live: Dictionary = {}
var pending_device: Dictionary = {}
var embedded := false
var advanced := false
var testing := false
var action_names: Dictionary = {}
var other_live: Dictionary = {}
func _ready() -> void:
 theme=load("res://assets/ui/theme.tres")
 process_mode = Node.PROCESS_MODE_ALWAYS
 if not embedded:set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 else:add_theme_stylebox_override("panel",StyleBoxEmpty.new())
 var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left",40);margin.add_theme_constant_override("margin_right",40);margin.add_theme_constant_override("margin_top",24);margin.add_theme_constant_override("margin_bottom",24);add_child(margin)
 body = VBoxContainer.new();body.add_theme_constant_override("separation",9);margin.add_child(body)
 router.binding_changed.connect(refresh,CONNECT_DEFERRED)
 router.binding_conflict.connect(show_conflict)
 refresh()
func label(text: String, parent: Node = null) -> Label:
 if parent == null: parent = body
 var node := Label.new();node.text=text;node.add_theme_font_size_override("font_size",22);parent.add_child(node);return node
func button(text: String, callback: Callable, parent: Node = null) -> Button:
 if parent == null: parent = body
 var node := Button.new();node.text=text;node.custom_minimum_size.y=48;node.pressed.connect(callback);parent.add_child(node);return node
func refresh() -> void:
 for child in body.get_children(): body.remove_child(child);child.queue_free()
 live.clear()
 other_live.clear()
 if not embedded:label("CONTROLS / PLAYER %d" % (slot+1)).add_theme_font_size_override("font_size",30)
 var tabs := HBoxContainer.new();body.add_child(tabs)
 for i in 2:
  var target := i
  button(("✓ " if i==slot else "")+"Player %d" % (i+1),func():slot=target;refresh(),tabs)
 button("BACK",func():pending_device={};router.cancel_capture();closed.emit(),tabs)
 button("Test Controls" if not testing else "Back to Bindings",func():testing=not testing;refresh(),tabs)
 button("Advanced" if not advanced else "Simple",func():advanced=not advanced;refresh(),tabs)
 button("Identify Controller",func():router.identify(slot),tabs)
 button("Press A to Assign",func():router.begin_claim(slot),tabs)
 var devices := OptionButton.new();body.add_child(devices)
 devices.add_item("Keyboard");devices.set_item_metadata(0,{"kind":"keyboard","device":-1})
 devices.add_item("Auto · first available controller, or keyboard");devices.set_item_metadata(1,{"kind":"auto","device":-1})
 for id in Input.get_connected_joypads():
  for mode in ["gamepad","wheel"]:
   devices.add_item("%s / %s" % [router.device_label(id),mode.to_upper()]);devices.set_item_metadata(devices.item_count-1,{"kind":mode,"device":id})
 var p := router.players[slot]
 var selected := -1
 for i in devices.item_count:
  var data: Dictionary = devices.get_item_metadata(i)
  if data.kind==p.kind and int(data.device)==p.device:selected=i
 if p.preference=="auto":selected=1
 if selected < 0:
  devices.add_item("DISCONNECTED / choose device");devices.set_item_disabled(devices.item_count-1,true);selected=devices.item_count-1
 devices.select(selected)
 devices.item_selected.connect(func(index: int):
  var data: Dictionary=devices.get_item_metadata(index)
  if data.kind=="auto":router.set_automatic(slot)
  elif data.kind!="keyboard" and ambiguous_device(int(data.device)):
   pending_device=data;status.text="CONFIRM PLAYER %d: press any button on the selected device #%d. Escape cancels." % [slot+1,int(data.device)]
  elif not router.assign(slot,data.kind,data.device):status.text=router.last_error)
 status=label(router.last_error if not router.last_error.is_empty() else "Press a button. See it light up." if testing else "Choose an action to change its button. Esc cancels.")
 status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var scroll:=ScrollContainer.new();scroll.follow_focus=true;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(scroll)
 var rows:=VBoxContainer.new();rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(rows)
 for action in LeoPlayerInput.ACTIONS:
  var target: String=action
  var row:=HBoxContainer.new();rows.add_child(row)
  var title:=label(action.replace("_"," ").to_upper()+(" · "+String(action_names.get(action,"Unassigned")) if action.begins_with("vehicle_action_") else ""),row);title.custom_minimum_size.x=255
  var bind:=button(p.describe(action),func():router.start_capture(slot,target);status.text="Player %d: press a key/button or move fully toward %s. Escape cancels." % [slot+1,target],row);bind.custom_minimum_size.x=360
  bind.disabled=testing
  var value_label:=label("○",row);live[action]=value_label
  if testing and router.active_slots==2:
   var other:=label("○",row);other_live[action]=other
  var entries: Array=p.bindings.get(action,[])
  if advanced and not entries.is_empty() and entries[0].get("type")=="axis":
   var entry: Dictionary=entries[0]
   for field in ["rest","pressed","deadzone","sensitivity"]:
    var key: String=field
    var spin:=SpinBox.new();spin.min_value=.25 if field=="sensitivity" else (0. if field=="deadzone" else -1.);spin.max_value=3. if field=="sensitivity" else (.5 if field=="deadzone" else 1.);spin.step=.01;spin.value=float(entry.get(field,1. if field in ["pressed","sensitivity"] else .03 if field=="deadzone" else 0.));spin.custom_minimum_size.x=105;spin.tooltip_text=field;row.add_child(spin)
    spin.value_changed.connect(func(value: float):
     if key in ["rest","pressed"] and absf(value-float(entry.get("pressed" if key=="rest" else "rest",0.)))<.1:status.text="Rest and full travel must differ by at least 0.1.";return
     entry[key]=value;router.save_profiles())
 button("Reset This Player",func():p.reset_defaults(p.kind);p.keyboard_preset="solo";p.custom_bindings=false;p.solo_bindings.clear();p.keyboard_profiles.clear();router.configure_keyboards(router.active_slots);router.save_profiles();refresh()).grab_focus()
 if testing:label("Player %d lights on the left · Player %d on the right" % [slot+1,2-slot])
 if advanced:
  label("Axis fields: rest / full travel / deadzone / sensitivity. Bind steering from centre.")
  label("Combined pedals use opposite ends. Wheel force feedback is unavailable.")
func _process(_dt: float) -> void:
 if not router:return
 var p:=router.players[slot]
 for action in live:
  if is_instance_valid(live[action]):
   live[action].text="● Pressed" if p.value(action)>.5 else "○"
   live[action].modulate=Color("43e7ef") if p.value(action)>.5 else Color("b9c7d6")
  if other_live.has(action):other_live[action].text="● Pressed" if router.players[1-slot].value(action)>.5 else "○"
func _exit_tree() -> void:
 pending_device={}
 if router:router.cancel_capture()
 if router and router.binding_changed.is_connected(refresh):router.binding_changed.disconnect(refresh)
 if router and router.binding_conflict.is_connected(show_conflict):router.binding_conflict.disconnect(show_conflict)

func show_conflict() -> void:
 for child in body.get_children():body.remove_child(child);child.queue_free()
 live.clear();other_live.clear()
 label("That key is already driving another action.")
 button("Swap Binding",func():router.resolve_conflict("swap");refresh()).grab_focus()
 button("Choose Another Key",func():router.resolve_conflict("retry");refresh())
 button("Cancel",func():router.resolve_conflict("cancel");refresh())

func ambiguous_device(id: int) -> bool:
 var identity:=router.fingerprint(id)
 var matches:=0
 for device in Input.get_connected_joypads():
  if router.fingerprint(device)==identity:matches+=1
 return matches>1

func _input(event: InputEvent) -> void:
 if router.claim_slot>=0 or (event is InputEventJoypadButton and router.claimed_releases.has(event.device)):
  router.claim_event(event);return
 if not pending_device.is_empty():
  if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE):
   pending_device={};refresh()
  elif event is InputEventJoypadButton and event.pressed and event.device==int(pending_device.device):
   var data:=pending_device;pending_device={}
   if not router.assign(slot,data.kind,data.device):status.text=router.last_error
  get_viewport().set_input_as_handled();return
 if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE):
  if router.capture_slot>=0:router.cancel_capture();refresh()
  else:closed.emit()
  get_viewport().set_input_as_handled()
