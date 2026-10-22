class_name LeoInputRouter
extends Node
signal command(slot: int, action: String)
signal device_lost(slot: int)
signal binding_changed
var players: Array[LeoPlayerInput] = [LeoPlayerInput.new("keyboard"),LeoPlayerInput.new("gamepad")]
var settings_path := "user://local_inputs.cfg"
var active_slots := 1
var capture_slot := -1
var capture_action := ""
var capture_rest: Dictionary = {}
var last_error := ""
func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 Input.joy_connection_changed.connect(_connection)
 load_profiles()
func fingerprint(id: int) -> Dictionary:
 var info := Input.get_joy_info(id)
 return {"guid":Input.get_joy_guid(id),"name":Input.get_joy_name(id),"serial":str(info.get("serial_number",""))}
func assign(slot: int, kind: String, id: int = -1, save: bool = true) -> bool:
 last_error = ""
 for i in players.size():
  if i == slot: continue
  if kind == "keyboard" and players[i].kind == "keyboard": last_error = "Only one keyboard player is allowed. Change the other player's device first."
  if kind != "keyboard" and id >= 0 and players[i].kind != "keyboard" and players[i].device == id: last_error = "This device is already assigned to the other player."
 if not last_error.is_empty(): return false
 var p := players[slot]
 if p.kind != kind: p.reset_defaults(kind)
 p.device = id if kind != "keyboard" else -1
 p.identity = fingerprint(id) if id in Input.get_connected_joypads() else {}
 p.clear()
 if save: save_profiles()
 binding_changed.emit()
 return true
func ready_problem(slot: int) -> String:
 var p := players[slot]
 if p.kind != "keyboard" and not p.device in Input.get_connected_joypads(): return "Player %d: choose a connected controller or wheel." % (slot+1)
 for action in ["accelerate","brake","left","right"]:
  if p.bindings.get(action,[]).is_empty(): return "Player %d: bind %s." % [slot+1,action]
 return ""
func clear_all() -> void:
 for p in players: p.clear()
func _input(event: InputEvent) -> void:
 if capture_slot >= 0:
  _capture(event); return
 feed(event)
func feed(event: InputEvent) -> void:
 for slot in players.size():
  for action in players[slot].feed(event):
   if slot < active_slots: command.emit(slot,action)
func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT: clear_all()
func _connection(id: int, connected: bool) -> void:
 if connected:
  binding_changed.emit(); return
 for i in players.size():
  if players[i].device == id:
   players[i].device = -1; players[i].clear()
   if i < active_slots: device_lost.emit(i)
 binding_changed.emit()
func save_profiles() -> Error:
 var cfg := ConfigFile.new()
 for i in players.size(): cfg.set_value("player_%d" % i,"profile",players[i].serialize())
 return cfg.save(settings_path)
func load_profiles() -> void:
 var cfg := ConfigFile.new()
 if cfg.load(settings_path) != OK: return
 var claimed: Array[int] = []
 for i in players.size():
  var data: Variant = cfg.get_value("player_%d" % i,"profile",{})
  if data is Dictionary and not data.is_empty(): players[i].restore(data)
  var p := players[i]
  if p.kind == "keyboard": continue
  var matches: Array[int] = []
  for id in Input.get_connected_joypads():
   if fingerprint(id) == p.identity and not id in claimed: matches.append(id)
  if matches.size() == 1:
   p.device = matches[0]; claimed.append(p.device)
 if players[0].kind == "keyboard" and players[1].kind == "keyboard": players[1].reset_defaults("gamepad")
func start_capture(slot: int, action: String) -> void:
 capture_slot = slot; capture_action = action
 capture_rest.clear()
 var p := players[slot]
 if p.device in Input.get_connected_joypads():
  for axis in JOY_AXIS_MAX: capture_rest[axis] = Input.get_joy_axis(p.device,axis)
 p.clear()
func cancel_capture() -> void:
 capture_slot = -1; capture_action = ""
 clear_all()
func _capture(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
  cancel_capture(); binding_changed.emit(); get_viewport().set_input_as_handled(); return
 var p := players[capture_slot]
 if not p.accepts(event): return
 var binding := {}
 if event is InputEventKey and event.pressed:
  binding = {"type":"key","index":event.physical_keycode if event.physical_keycode else event.keycode}
 elif event is InputEventJoypadButton and event.pressed:
  binding = {"type":"button","index":event.button_index}
 elif event is InputEventJoypadMotion:
  var rest := float(capture_rest.get(event.axis,0.))
  if absf(event.axis_value-rest)>.4:
   binding = {"type":"axis","index":event.axis,"rest":rest,"pressed":event.axis_value,"deadzone":.03 if p.kind == "wheel" else .16,"sensitivity":1.}
 if not binding.is_empty():
  p.bindings[capture_action] = [binding]
  cancel_capture(); save_profiles(); binding_changed.emit()
 get_viewport().set_input_as_handled()
