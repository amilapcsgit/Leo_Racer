class_name LeoPlayerInput
extends RefCounted
const ACTIONS := ["accelerate","brake","left","right","drift","boost","recover","horn","pause_race","photo"]
var kind := "keyboard"
var device := -1
var identity: Dictionary = {}
var bindings: Dictionary = {}
var keys: Dictionary = {}
var buttons: Dictionary = {}
var axes: Dictionary = {}
var pending: Dictionary = {}
var test_values: Dictionary = {}
var preference := "auto"
var keyboard_preset := "solo"
var custom_bindings := false
var solo_bindings: Dictionary = {}
var stored_bindings: Dictionary = {}
var keyboard_profiles: Dictionary = {}
func _init(input_kind: String = "keyboard") -> void: reset_defaults(input_kind)
func reset_defaults(input_kind: String) -> void:
 kind = input_kind
 bindings.clear()
 if kind == "keyboard":
  var defaults := {"accelerate":[KEY_W,KEY_UP],"brake":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"drift":[KEY_SPACE],"boost":[KEY_SHIFT],"recover":[KEY_R],"horn":[KEY_H],"pause_race":[KEY_P],"photo":[KEY_F8]}
  for action in defaults:
   bindings[action] = []
   for key in defaults[action]: bindings[action].append({"type":"key","index":key})
 else:
  for pair in [["drift",JOY_BUTTON_A],["boost",JOY_BUTTON_X],["recover",JOY_BUTTON_Y],["horn",JOY_BUTTON_B],["pause_race",JOY_BUTTON_START]]: bindings[pair[0]] = [{"type":"button","index":pair[1]}]
  set_axis("left",JOY_AXIS_LEFT_X,0.,-1.,.16)
  set_axis("right",JOY_AXIS_LEFT_X,0.,1.,.16)
  if kind == "gamepad":
   set_axis("accelerate",JOY_AXIS_TRIGGER_RIGHT,0.,1.,.05)
   set_axis("brake",JOY_AXIS_TRIGGER_LEFT,0.,1.,.05)
 clear()
func clear() -> void:
 keys.clear(); buttons.clear(); axes.clear(); pending.clear(); test_values.clear()
func set_axis(action: String, index: int, rest: float, pressed: float, deadzone: float = .03, sensitivity: float = 1.) -> bool:
 if absf(pressed-rest) < .1: return false
 bindings[action] = [{"type":"axis","index":index,"rest":rest,"pressed":pressed,"deadzone":clampf(deadzone,0.,.5),"sensitivity":clampf(sensitivity,.25,3.)}]
 return true
func value(action: String) -> float:
 var result := float(test_values.get(action,0.))
 for binding in bindings.get(action,[]):
  var n := int(binding.get("index",0))
  match str(binding.get("type","")):
   "key":
    var location := int(binding.get("location",0))
    var held := bool(keys.get("%d:%d" % [n,location],false)) if location else bool(keys.get(n,false))
    result = maxf(result,1. if held else 0.)
   "button": result = maxf(result,1. if buttons.get(n,false) else 0.)
   "axis":
    var rest := float(binding.get("rest",0.))
    var end := float(binding.get("pressed",1.))
    var raw := float(axes.get(n,rest))
    var strength := clampf((raw-rest)/(end-rest),0.,1.) if absf(end-rest)>.001 else 0.
    var deadzone := float(binding.get("deadzone",.03))
    strength = clampf((strength-deadzone)/maxf(.001,1.-deadzone),0.,1.)
    result = maxf(result,clampf(strength*float(binding.get("sensitivity",1.)),0.,1.))
 return result
func steering() -> float: return value("right")-value("left")
func throttle() -> float: return value("accelerate")-value("brake")
func consume(action: String) -> bool:
 var pressed: bool = pending.get(action,false)
 pending.erase(action)
 return pressed
func accepts(event: InputEvent) -> bool:
 if event is InputEventKey: return kind == "keyboard" and not event.echo
 return kind != "keyboard" and device >= 0 and event.device == device and (event is InputEventJoypadButton or event is InputEventJoypadMotion)
func feed(event: InputEvent) -> Array[String]:
 var edges: Array[String] = []
 if not accepts(event): return edges
 var before := {}
 for action in ACTIONS: before[action] = value(action)>.5
 if event is InputEventKey:
  var code: int = event.physical_keycode if event.physical_keycode else event.keycode
  keys["%d:%d" % [code,event.location]] = event.pressed
  var held := false
  for location in [0,1,2]: held = held or bool(keys.get("%d:%d" % [code,location],false))
  keys[code] = held
 elif event is InputEventJoypadButton: buttons[event.button_index] = event.pressed
 elif event is InputEventJoypadMotion: axes[event.axis] = event.axis_value
 for action in ACTIONS:
  if value(action)>.5 and not before[action]:
   pending[action] = true; edges.append(action)
 return edges
func describe(action: String) -> String:
 var labels: Array[String] = []
 for binding in bindings.get(action,[]):
  var n := int(binding.get("index",0))
  match str(binding.get("type","")):
   "key": labels.append(("Left " if int(binding.get("location",0))==1 else "Right " if int(binding.get("location",0))==2 else "")+OS.get_keycode_string(n))
   "button": labels.append({JOY_BUTTON_A:"A",JOY_BUTTON_B:"B",JOY_BUTTON_X:"X",JOY_BUTTON_Y:"Y",JOY_BUTTON_START:"Start"}.get(n,"Button %d" % n))
   "axis":
    if kind=="gamepad":labels.append("RT" if n==JOY_AXIS_TRIGGER_RIGHT else "LT" if n==JOY_AXIS_TRIGGER_LEFT else "Left Stick ←" if action=="left" else "Left Stick →" if action=="right" else "Stick")
    else:labels.append("Steering Wheel" if action in ["left","right"] else "Accelerator" if action=="accelerate" else "Brake Pedal" if action=="brake" else "Wheel Axis")
 return " / ".join(labels) if not labels.is_empty() else "UNBOUND"
func serialize() -> Dictionary: return {"version":2,"preference":preference,"keyboard_preset":keyboard_preset,"custom_bindings":custom_bindings,"solo_bindings":solo_bindings.duplicate(true),"stored_bindings":stored_bindings.duplicate(true),"keyboard_profiles":keyboard_profiles.duplicate(true),"kind":kind,"identity":identity.duplicate(true),"bindings":bindings.duplicate(true)}
func restore(data: Dictionary) -> void:
 reset_defaults(str(data.get("kind","keyboard")))
 preference=str(data.get("preference","manual"))
 keyboard_preset=str(data.get("keyboard_preset","solo"))
 custom_bindings=bool(data.get("custom_bindings",int(data.get("version",1))<2))
 solo_bindings=data.get("solo_bindings",{}).duplicate(true)
 stored_bindings=data.get("stored_bindings",{}).duplicate(true)
 keyboard_profiles=data.get("keyboard_profiles",{}).duplicate(true)
 identity = data.get("identity",{}).duplicate(true)
 var incoming: Dictionary = data.get("bindings",{})
 if int(data.get("version",1))<2:custom_bindings=incoming!=bindings
 for action in ACTIONS:
  if incoming.has(action) and incoming[action] is Array:
   var valid: Array = []
   for binding in incoming[action]:
    if not binding is Dictionary: continue
    var type := str(binding.get("type",""))
    if not type in ["key","button","axis"] or int(binding.get("index",-1)) < 0: continue
    if type == "axis" and absf(float(binding.get("pressed",1.))-float(binding.get("rest",0.)))<.1: continue
    valid.append(binding.duplicate(true))
   bindings[action] = valid
 device = -1
 if int(data.get("version",1))<2 and kind=="gamepad" and identity.is_empty() and not custom_bindings:preference="auto"
 clear()

func use_keyboard_preset(preset: String) -> void:
 if kind!="keyboard" or preset==keyboard_preset:return
 keyboard_profiles[keyboard_preset]=bindings.duplicate(true)
 if keyboard_profiles.has(preset):
  bindings=keyboard_profiles[preset].duplicate(true);keyboard_preset=preset;clear();return
 if preset=="solo":
  if not solo_bindings.is_empty():bindings=solo_bindings.duplicate(true)
  else:reset_defaults("keyboard")
  keyboard_preset=preset;clear();return
 if keyboard_preset=="solo":solo_bindings=bindings.duplicate(true)
 var original: Dictionary=solo_bindings.duplicate(true)
 var baseline:=LeoPlayerInput.new("keyboard")
 reset_defaults("keyboard")
 var defaults: Dictionary={"accelerate":KEY_W,"brake":KEY_S,"left":KEY_A,"right":KEY_D,"drift":KEY_SPACE,"boost":KEY_SHIFT,"recover":KEY_R,"horn":KEY_H,"pause_race":KEY_P,"photo":KEY_F8} if preset=="shared1" else {"accelerate":KEY_UP,"brake":KEY_DOWN,"left":KEY_LEFT,"right":KEY_RIGHT,"drift":KEY_CTRL,"boost":KEY_SHIFT,"recover":KEY_BACKSPACE,"horn":KEY_ENTER,"pause_race":KEY_P,"photo":KEY_F9}
 for action in defaults:bindings[action]=[{"type":"key","index":defaults[action]}]
 bindings.boost[0]["location"]=1 if preset=="shared1" else 2
 if preset=="shared2":bindings.drift[0]["location"]=2
 for action in original:
  if original[action]!=baseline.bindings.get(action,[]):bindings[action]=original[action].duplicate(true)
 keyboard_preset=preset;clear()

func switch_kind(target: String) -> void:
 stored_bindings[kind]={"bindings":bindings.duplicate(true),"custom_bindings":custom_bindings,"keyboard_preset":keyboard_preset,"solo_bindings":solo_bindings.duplicate(true)}
 reset_defaults(target);keyboard_preset="solo";custom_bindings=false;solo_bindings={}
 var saved: Dictionary=stored_bindings.get(target,{})
 if not saved.is_empty():
  bindings=saved.get("bindings",bindings).duplicate(true);custom_bindings=bool(saved.get("custom_bindings",false));keyboard_preset=str(saved.get("keyboard_preset","solo"));solo_bindings=saved.get("solo_bindings",{}).duplicate(true)
 clear()

func inject_test(action: String, strength: float) -> void:
 var before := value(action)
 test_values[action] = clampf(strength,0.,1.)
 if before<=.5 and strength>.5: pending[action]=true
