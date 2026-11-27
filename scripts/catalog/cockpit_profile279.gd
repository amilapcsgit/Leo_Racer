extends RefCounted
## Reviewed core presentation only. Positions are authored model metres; camera
## eyes remain in the existing resolved-vehicle camera_views interface.
static var profiles: Dictionary = {}

static func for_vehicle(id: String) -> Dictionary:
	if profiles.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/config/cockpit-profiles-v279.json"))
		if parsed is Dictionary: profiles = parsed.get("vehicles", {})
	return profiles.get(id, {})

static func node(body: Node3D, label: String) -> Node3D:
	return body.find_child(label, true, false) as Node3D

static func vector(data: Dictionary, key: String, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	var value: Variant = data.get(key, [])
	return LeoVehicleCodec.vector(value) if LeoVehicleCodec.finite_vector(value) else fallback
