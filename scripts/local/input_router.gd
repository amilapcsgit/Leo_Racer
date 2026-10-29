class_name LeoInputRouter
extends Node
signal command(slot: int, action: String)
signal device_lost(slot: int)
signal binding_changed
var players: Array[LeoPlayerInput] = [LeoPlayerInput.new("keyboard"),LeoPlayerInput.new("gamepad")]
var settings_path := "user://local_inputs.cfg"
var active_slots := 1
var pad_numbers: Dictionary = {}
var next_pad_number := 1
var claim_slot := -1
var claimed_releases: Dictionary = {}
var capture_slot := -1
var capture_action := ""
var capture_rest: Dictionary = {}
var last_error := ""
var gameplay_enabled := false
var controls_testing := false
var assignment_locked := false
var pending_binding: Dictionary = {}
signal binding_conflict
func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 Input.joy_connection_changed.connect(_connection)
 load_profiles()
func fingerprint(id: int) -> Dictionary:
 var info := Input.get_joy_info(id)
 return {"guid":Input.get_joy_guid(id),"name":Input.get_joy_name(id),"serial":str(info.get("serial_number",""))}
func connected_devices() -> Array[int]:
 return Input.get_connected_joypads()
func assign(slot: int, kind: String, id: int = -1, save: bool = true) -> bool:
 last_error = ""
 stop_feedback()
 if slot<0 or slot>=players.size():return false
 var connected:=connected_devices()
 var former_kind:=players[slot].kind
 var former_id:=players[slot].device
 for i in players.size():
  if i == slot: continue
  if kind != "keyboard" and id >= 0 and players[i].kind != "keyboard" and players[i].device == id:
   var replacement:=-1
   connected.sort()
   for candidate in connected:
    if candidate!=id and candidate!=former_id:replacement=candidate;break
   if replacement<0 and former_kind!="keyboard" and former_id!=id and former_id in connected:replacement=former_id
   var displaced:=players[i]
   var target_kind:=former_kind if replacement==former_id and replacement>=0 else "gamepad" if replacement>=0 else "keyboard"
   if displaced.kind!=target_kind:displaced.switch_kind(target_kind)
   displaced.device=replacement
   displaced.identity=fingerprint(replacement) if replacement>=0 else {}
   displaced.preference="manual"
   displaced.clear()
 var p := players[slot]
 p.preference="manual"
 if p.kind != kind:p.switch_kind(kind)
 p.device = id if kind != "keyboard" else -1
 p.identity = fingerprint(id) if id in connected else {}
 p.clear()
 configure_keyboards(active_slots)
 if save: save_profiles()
 binding_changed.emit()
 return true
func ready_problem(slot: int) -> String:
 var p := players[slot]
 if p.kind != "keyboard" and not p.device in connected_devices(): return "Player %d: choose a connected controller or wheel." % (slot+1)
 for action in ["accelerate","brake","left","right"]:
  if p.bindings.get(action,[]).is_empty(): return "Player %d: bind %s." % [slot+1,action]
 if active_slots==2 and players[0].kind=="keyboard" and players[1].kind=="keyboard":
  for action in LeoPlayerInput.ACTIONS:
   for binding in p.bindings.get(action,[]):
    if not conflicts(slot,action,binding).is_empty():return "Keyboard controls overlap. Open Controls to choose another key."
 return ""
func stop_feedback() -> void:
 if is_inside_tree():get_tree().call_group("haptics","stop_all")
func clear_all() -> void:
 stop_feedback()
 for p in players:
  if p.kind=="gamepad" and p.device>=0:Input.stop_joy_vibration(p.device)
  p.clear()
func begin_claim(slot: int) -> void:
 clear_all();claim_slot=slot;binding_changed.emit()
func device_label(device: int) -> String:
 var devices:=connected_devices();devices.sort()
 if not device in devices:return "Disconnected controller"
 var owner:="Unassigned"
 for slot in active_slots:
  if players[slot].kind!="keyboard" and players[slot].device==device:owner="Player %d" % (slot+1)
 for id in devices:
  if not pad_numbers.has(id):pad_numbers[id]=next_pad_number;next_pad_number+=1
 var name:=String(fingerprint(device).get("name","Controller"))
 if "xbox" in name.to_lower() or "xinput" in name.to_lower():name="Xbox Controller"
 return "%s · Pad %d · %s" % [name,int(pad_numbers[device]),owner]
func identify(slot: int) -> void:
 var p:=players[slot]
 if p.kind!="keyboard" and p.device>=0:get_tree().call_group("haptics","play",p.device,"identify",1.)
func claim_event(event: InputEvent) -> bool:
 if event is InputEventJoypadButton and claimed_releases.has(event.device):
  if not event.pressed and event.button_index==JOY_BUTTON_A:claimed_releases.erase(event.device)
  get_viewport().set_input_as_handled();return true
 if claim_slot<0:return false
 if (event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE) or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_B):
  claim_slot=-1;binding_changed.emit()
 elif event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_A:
  var slot:=claim_slot;claim_slot=-1
  claimed_releases[event.device]=true
  assign(slot,"gamepad",event.device)
 get_viewport().set_input_as_handled();return true
func _input(event: InputEvent) -> void:
 if claim_event(event):return
 if capture_slot >= 0:
  _capture(event); return
 if gameplay_enabled or controls_testing:feed(event)
func feed(event: InputEvent) -> void:
 if event is InputEventMouseButton or event is InputEventMouseMotion:
  var owner:=0
  if active_slots==2 and players[0].kind!="keyboard" and players[1].kind=="keyboard":owner=1
  if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:players[owner].orbit_dragging=event.pressed
  if event is InputEventMouseMotion and players[owner].orbit_dragging:players[owner].mouse_orbit+=event.relative
  return
 var pause_sent:=false
 for slot in players.size():
  for action in players[slot].feed(event):
   if slot < active_slots and gameplay_enabled:
    if action=="pause_race" and pause_sent:continue
    if action=="pause_race":
     pause_sent=true
     if is_inside_tree():get_viewport().set_input_as_handled()
    command.emit(slot,action)
func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT: claim_slot=-1;clear_all()
func _connection(id: int, connected: bool) -> void:
 stop_feedback()
 if connected:
  var identity:=fingerprint(id)
  var owners: Array[LeoPlayerInput]=[]
  var matches:=0
  for other_id in Input.get_connected_joypads():
   if fingerprint(other_id)==identity:matches+=1
  for p in players:
   if p.kind!="keyboard" and p.identity==identity:owners.append(p)
  if owners.size()==1 and matches==1 and owners[0].device<0:owners[0].device=id;owners[0].clear()
  if not assignment_locked:resolve_automatic(active_slots)
  var audio:=get_tree().get_first_node_in_group("ui_audio")
  if audio:audio.cue("connect")
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
 var added: Array=[]
 for i in players.size():
  var data: Variant = cfg.get_value("player_%d" % i,"profile",{})
  if data is Dictionary and not data.is_empty():
   players[i].restore(data)
   if int(data.get("version",1))<3:
    for action in LeoPlayerInput.FEATURE_ACTIONS:
     if not data.get("bindings",{}).has(action):added.append({"slot":i,"action":action})
 for entry in added:
  var p:=players[int(entry.slot)]
  for binding in p.bindings.get(entry.action,[]):
   if not conflicts(int(entry.slot),entry.action,binding).is_empty():p.bindings[entry.action]=[];break
 var identities: Dictionary={}
 for id in Input.get_connected_joypads():identities[id]=fingerprint(id)
 restore_assignments(Input.get_connected_joypads(),identities)
func start_capture(slot: int, action: String) -> void:
 capture_slot = slot; capture_action = action
 capture_rest.clear()
 var p := players[slot]
 if p.device in Input.get_connected_joypads():
  for axis in JOY_AXIS_MAX: capture_rest[axis] = Input.get_joy_axis(p.device,axis)
 p.clear()
func cancel_capture() -> void:
 claim_slot=-1
 capture_slot = -1; capture_action = ""
 clear_all()
func _capture(event: InputEvent) -> void:
 if players[capture_slot].kind=="keyboard" and event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_B:
  cancel_capture();binding_changed.emit();get_viewport().set_input_as_handled();return
 if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
  cancel_capture(); binding_changed.emit(); get_viewport().set_input_as_handled(); return
 var p := players[capture_slot]
 if not p.accepts(event): return
 var binding := {}
 if event is InputEventKey and event.pressed:
  binding = {"type":"key","index":event.physical_keycode if event.physical_keycode else event.keycode,"location":event.location}
 elif event is InputEventJoypadButton and event.pressed:
  binding = {"type":"button","index":event.button_index}
 elif event is InputEventJoypadMotion:
  var rest := float(capture_rest.get(event.axis,0.))
  if absf(event.axis_value-rest)>.4:
   binding = {"type":"axis","index":event.axis,"rest":rest,"pressed":event.axis_value,"deadzone":.03 if p.kind == "wheel" else .16,"sensitivity":1.}
 if not binding.is_empty():
  if not conflicts(capture_slot,capture_action,binding).is_empty():
   pending_binding={"slot":capture_slot,"action":capture_action,"binding":binding}
   cancel_capture();binding_conflict.emit();get_viewport().set_input_as_handled();return
  p.bindings[capture_action] = [binding];p.custom_bindings=true
  cancel_capture(); save_profiles(); binding_changed.emit()
 get_viewport().set_input_as_handled()

func configure_keyboards(count: int) -> void:
 var shared:=count==2 and players[0].kind=="keyboard" and players[1].kind=="keyboard"
 for slot in players.size():players[slot].use_keyboard_preset("shared%d" % (slot+1) if shared else "solo")

func resolve_automatic(count: int, devices: Array[int] = [], identities: Dictionary = {}, injected: bool = false) -> void:
 if assignment_locked:return
 active_slots=count
 var connected: Array[int]=devices.duplicate() if injected else Input.get_connected_joypads()
 connected.sort()
 var used: Array[int]=[]
 var reserved: Dictionary={}
 for slot in count:
  if players[slot].device in connected:reserved[players[slot].device]=slot
 for slot in count:
  var p:=players[slot]
  if p.preference=="manual" and p.kind!="keyboard" and p.device in connected:used.append(p.device)
 for slot in count:
  var p:=players[slot]
  if p.preference!="auto":continue
  var chosen: int=-1
  if p.device in connected and not p.device in used:chosen=p.device
  else:
   for id in connected:
    if not id in used and int(reserved.get(id,slot))==slot and (injected or Input.is_joy_known(id)):chosen=id;break
  var target:="gamepad" if chosen>=0 else "keyboard"
  if p.kind!=target:
   p.switch_kind(target)
  p.device=chosen
  p.identity=identities.get(chosen,{}) if injected else fingerprint(chosen) if chosen>=0 else {}
  if chosen>=0:used.append(chosen)
  p.clear()
 configure_keyboards(count)
 binding_changed.emit()

func set_automatic(slot: int) -> void:
 players[slot].preference="auto"
 # Explicit recovery can resolve this slot without moving another player's device.
 var locked:=assignment_locked;assignment_locked=false
 resolve_automatic(active_slots);assignment_locked=locked
 save_profiles()

func conflicts(slot: int, action: String, binding: Dictionary) -> Array[Dictionary]:
 var result: Array[Dictionary]=[]
 if action in ["pause_race","photo"]:return result
 if binding.get("type")!="key":
  for other_action in players[slot].bindings:
   if other_action==action:continue
   for entry in players[slot].bindings[other_action]:
    if LeoPlayerInput.binding_overlap(binding,entry):result.append({"slot":slot,"action":other_action,"binding":entry})
  return result
 for other_slot in active_slots:
  var other:=players[other_slot]
  if other.kind!="keyboard":continue
  for other_action in other.bindings:
   if other_action in ["pause_race","photo"] or (other_slot==slot and other_action==action):continue
   for entry in other.bindings[other_action]:
    if entry.get("type")!="key" or entry.get("index")!=binding.get("index"):continue
    var a:=int(entry.get("location",0));var b:=int(binding.get("location",0))
    if a==0 or b==0 or a==b:result.append({"slot":other_slot,"action":other_action,"binding":entry})
 return result

func resolve_conflict(choice: String) -> void:
 if pending_binding.is_empty():return
 var data:=pending_binding;pending_binding={}
 if choice=="cancel":return
 if choice=="retry":start_capture(data.slot,data.action);return
 var matches:=conflicts(data.slot,data.action,data.binding)
 var p:=players[int(data.slot)]
 var previous: Array=p.bindings.get(data.action,[]).duplicate(true)
 # A swap is safe only when one action owns the key and it can receive the old binding.
 if matches.size()!=1 or previous.is_empty():last_error="Choose another key for this action.";return
 var match_data: Dictionary=matches[0]
 for old in previous:
  if old.get("type")=="key" and data.binding.get("type")=="key" and old.get("index")==data.binding.get("index"):
   var old_location:=int(old.get("location",0));var new_location:=int(data.binding.get("location",0))
   if old_location==0 or new_location==0 or old_location==new_location:last_error="Those keys still overlap. Choose another key.";return
  var overlaps:=conflicts(int(match_data.slot),str(match_data.action),old)
  overlaps=overlaps.filter(func(item):return not (item.slot==data.slot and item.action==data.action))
  if not overlaps.is_empty():last_error="That swap would overlap another action. Choose another key.";return
 players[int(match_data.slot)].bindings[match_data.action]=previous
 players[int(match_data.slot)].custom_bindings=true
 p.bindings[data.action]=[data.binding];p.custom_bindings=true
 clear_all();save_profiles();binding_changed.emit()

func restore_assignments(devices: Array[int], identities: Dictionary) -> void:
 # Compare against ALL saved owners and ALL connected devices. A lone plugged-in
 # twin still cannot identify itself as P1 or P2 when both saved GUIDs match.
 for slot in players.size():
  var p:=players[slot]
  if p.kind=="keyboard":continue
  p.device=-1;p.clear()
  var duplicate_owner:=false
  for other in players:
   if other!=p and other.kind!="keyboard" and other.identity==p.identity:duplicate_owner=true
  var matches: Array[int]=[]
  for id in devices:
   if identities.get(id,{})==p.identity:matches.append(id)
  if not duplicate_owner and matches.size()==1 and not p.identity.is_empty():p.device=matches[0]
