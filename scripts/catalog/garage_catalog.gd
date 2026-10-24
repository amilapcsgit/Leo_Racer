@tool
class_name GarageCatalog
extends Resource
@export var vehicles: Array[VehicleDefinition] = []
@export var drivers: Array[DriverDefinition] = []
const PATH := "res://assets/catalog/runtime/catalog.tres"
const LEGACY_DRIVERS := ["hedgehog","lion","elephant","parrot","human"]
const LEGACY_VEHICLES := ["blue","coral","aqua","pink","formula_blue","formula_red","roadster_gold","race_tuk","race_bus"]
static var _discovered: GarageCatalog
static var _generation := -1

static func shared() -> GarageCatalog:
	if LeoVehicleLibrary.legacy():return load(PATH) as GarageCatalog
	if LeoVehicleLibrary.generation==0:LeoVehicleLibrary.discover()
	if not _discovered or _generation!=LeoVehicleLibrary.generation:
		_discovered=GarageCatalog.new()
		# Driver-only catalog has no dependency on the installed vehicle roster.
		var driver_catalog:=load("res://assets/catalog/runtime/drivers.tres") as GarageCatalog
		_discovered.drivers.assign(driver_catalog.drivers);_discovered.vehicles.assign(LeoVehicleLibrary.entries)
		_generation=LeoVehicleLibrary.generation
	return _discovered

func vehicle(key: StringName) -> VehicleDefinition:
	for entry in vehicles:
		if entry.id==key: return entry
	return null

func driver(key: StringName) -> DriverDefinition:
	for entry in drivers:
		if entry.id==key: return entry
	return null

func vehicle_index(key: StringName) -> int:
	for i in vehicles.size():
		if vehicles[i].id==key: return i
	return 0

func driver_index(key: StringName) -> int:
	for i in drivers.size():
		if drivers[i].id==key: return i
	return 0

func migrate(cfg: ConfigFile) -> Vector2i:
	var d: String = cfg.get_value("game","driver_id",LEGACY_DRIVERS[clampi(int(cfg.get_value("game","driver",0)),0,LEGACY_DRIVERS.size()-1)])
	var v: String = cfg.get_value("game","vehicle_id",LEGACY_VEHICLES[clampi(int(cfg.get_value("game","kart",0)),0,LEGACY_VEHICLES.size()-1)])
	return Vector2i(driver_index(d),vehicle_index(v))

func problems() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	for v in vehicles:
		if ids.has(v.id): errors.append("Duplicate vehicle ID: "+String(v.id))
		ids[v.id]=true
		for issue in v.problems(): errors.append(String(v.id)+": "+issue)
		if v.driver_policy==VehicleDefinition.DriverPolicy.FIXED and not drivers.any(func(d):return d.id==v.fixed_driver_id): errors.append(String(v.id)+": unknown fixed driver")
	ids.clear()
	for d in drivers:
		if d.id.is_empty() or ids.has(d.id) or not d.seated_model or not d.standing_model or not d.setup_complete: errors.append("Incomplete driver: "+String(d.id))
		if not d.cabin_model and vehicles.any(func(v):return v.driver_policy==VehicleDefinition.DriverPolicy.CABIN):errors.append("Missing cabin pose: "+String(d.id))
		ids[d.id]=true
	return errors
