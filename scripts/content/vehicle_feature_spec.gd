extends RefCounted
## Bounded, data-only extension to Vehicle API 1.
static func path_ok(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length()<512 and not value.is_absolute_path() and not value.contains(":") and not ".." in value.replace("\\","/").split("/")

static func number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high

static func vector(value: Variant) -> bool:
	if not value is Array or value.size()!=3:return false
	for n in value:
		if not number(n,-360.,360.):return false
	return true

static func problems(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var lamps: Variant = data.get("lighting",[])
	if not lamps is Array or lamps.size()>16:errors.append("Lighting must contain at most 16 groups");return errors
	var light_count := 0
	for group in lamps:
		if not group is Dictionary or group.get("role","") not in ["head","tail","brake","reverse"]:errors.append("Invalid lamp role");continue
		var targets: Variant = group.get("targets",[])
		if not targets is Array or targets.size()>64:errors.append("Invalid lamp targets");continue
		if targets.is_empty() and not group.has("anchor"):errors.append("Lamp needs surfaces or an anchor")
		for target in targets:
			if not target is Dictionary or not path_ok(target.get("node")) or not target.get("material") is String or target.get("material","").is_empty():errors.append("Invalid lamp target")
		if group.has("running") and not group.running is bool:errors.append("Invalid running lamp state")
		if group.has("anchor"):
			light_count += 1
			if not vector(group.anchor):errors.append("Invalid lamp anchor")
		if group.has("rotation") and not vector(group.rotation):errors.append("Invalid lamp rotation")
		if not number(group.get("energy",1.),0.,8.) or not number(group.get("range",2.),.1,40.):errors.append("Invalid lamp range/energy")
	if light_count>8:errors.append("At most eight projected vehicle lights are supported")
	var actions: Variant = data.get("actions",[])
	if not actions is Array or actions.size()>2:errors.append("At most two vehicle actions are supported");return errors
	var slots: Array = []
	for action in actions:
		if not action is Dictionary:errors.append("Invalid vehicle action");continue
		var slot: Variant = action.get("slot",0)
		if not number(slot,1,2) or int(slot)!=float(slot) or slot in slots:errors.append("Invalid or duplicate action slot")
		slots.append(slot)
		if not action.get("name") is String or action.get("name","").is_empty() or String(action.get("name","")).length()>64:errors.append("Invalid action name")
		if not number(action.get("duration",1.2),.1,10.):errors.append("Invalid action duration")
		match action.get("type","transform"):
			"animation":
				if not path_ok(action.get("player")) or not action.get("clip") is String or action.get("clip","").is_empty():errors.append("Invalid action animation")
			"transform":
				var targets: Variant = action.get("targets",[])
				if not targets is Array or targets.is_empty() or targets.size()>16:errors.append("Action needs 1–16 targets");continue
				for target in targets:
					if not target is Dictionary or not path_ok(target.get("node")):errors.append("Invalid action target");continue
					for key in ["closed_position","open_position","closed_rotation","open_rotation"]:
						if target.has(key) and not vector(target[key]):errors.append("Invalid action pose")
			_:errors.append("Unsupported vehicle action type")
	return errors
