class_name LeoDefaultRoster
extends RefCounted
const PATH := "res://assets/config/default-roster-v1.json"
static var _data: Dictionary={}
static func data() -> Dictionary:
	if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data
static func ids() -> Array:
	return data().vehicles.map(func(row):return String(row.id))
static func ai_vehicles(catalog: GarageCatalog) -> Array[VehicleDefinition]:
	var result: Array[VehicleDefinition]=[]
	for key in ids():
		var vehicle:=catalog.vehicle(StringName(key))
		if vehicle:result.append(vehicle)
	return result
static func fallback(catalog: GarageCatalog) -> StringName:
	return &"bigster" if catalog.vehicle(&"bigster") else (catalog.vehicles[0].id if not catalog.vehicles.is_empty() else &"")
