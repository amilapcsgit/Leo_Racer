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
   "key": result = maxf(result,1. if keys.get(n,false) else 0.)
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
  keys[code] = event.pressed
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
   "key": labels.append(OS.get_keycode_string(n))
   "button": labels.append("Button %d" % n)
   "axis": labels.append("Axis %d (%+.2f to %+.2f)" % [n,binding.get("rest",0.),binding.get("pressed",1.)])
 return " / ".join(labels) if not labels.is_empty() else "UNBOUND"
func serialize() -> Dictionary: return {"kind":kind,"identity":identity.duplicate(true),"bindings":bindings.duplicate(true)}
func restore(data: Dictionary) -> void:
 reset_defaults(str(data.get("kind","keyboard")))
 identity = data.get("identity",{}).duplicate(true)
 var incoming: Dictionary = data.get("bindings",{})
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
 clear()

func inject_test(action: String, strength: float) -> void:
 var before := value(action)
 test_values[action] = clampf(strength,0.,1.)
 if before<=.5 and strength>.5: pending[action]=true
